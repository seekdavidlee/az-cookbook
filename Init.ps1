param($Name)
$region = "centralus"
$region2 = "eastus2"
$ResourceGroupName = $Name
$ErrorActionPreference = "Stop"

function CreateVirtualNetworkIfNotExist($ResourceGroupName, $Prefix, $Region) {

    $VirtualNetworkName = "$Region-${ResourceGroupName}vn"

    if (!(Get-AzVirtualNetwork -Name $VirtualNetworkName `
        -ResourceGroupName $ResourceGroupName `
        -ErrorAction SilentlyContinue)) {

        $frontendNsg = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName `
            -Location $Region -Name "$Region-frontend-nsg"
        $backendNsg = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName `
            -Location $Region -Name "$Region-backend-nsg"

        $frontendSubnet = New-AzVirtualNetworkSubnetConfig -Name "$Region-frontend-subnet" -AddressPrefix "${Prefix}.1.0/24" `
            -NetworkSecurityGroup $frontendNsg
        $backendSubnet = New-AzVirtualNetworkSubnetConfig -Name "$Region-backend-subnet"  -AddressPrefix "${Prefix}.2.0/24" `
            -NetworkSecurityGroup $backendNsg 
        
        New-AzVirtualNetwork -Name $VirtualNetworkName `
            -ResourceGroupName $ResourceGroupName `
            -Location $Region `
            -Subnet $frontendSubnet,$backendSubnet `
            -AddressPrefix "${Prefix}.0.0/16"
    } else {
        Write-Host "$VirtualNetworkName already exist"
    }    
}

function EnableSubnetAccessToStorage($ResourceGroupName, $Region, $AccountName) {

    $VirtualNetwork = Get-AzVirtualNetwork -Name "$Region-${ResourceGroupName}vn" `
        -ResourceGroupName $ResourceGroupName     

    $StorageServiceEndpoint = "Microsoft.Storage"
    Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VirtualNetwork | ForEach-Object {

        $subnetName = $_.Name
        if ($_.ServiceEndpoints) { 
            if (($_.ServiceEndpoints | Where { $_.Service -eq $StorageServiceEndpoint }).Count -gt 0) {
                Write-Host "$StorageServiceEndpoint service endpoint exist on $subnetName."
                return
            }
            
            $_.ServiceEndpoints
        }

        Set-AzVirtualNetworkSubnetConfig -Name $subnetName `
            -AddressPrefix $_.AddressPrefix `
            -VirtualNetwork $VirtualNetwork `
            -ServiceEndpoint $StorageServiceEndpoint | Set-AzVirtualNetwork

        # See: https://docs.microsoft.com/en-us/azure/cosmos-db/how-to-configure-vnet-service-endpoint
        # See: https://docs.microsoft.com/en-us/powershell/module/az.network/set-azvirtualnetworksubnetconfig?view=azps-3.4.0
        
        Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName `
            -Name $AccountName `
            -VirtualNetworkResourceId $_.Id
    }
}

$UserPrincipalName = (az ad signed-in-user show --query userPrincipalName).Replace('"','')

$tag = @{ "purpose"="system-operations" }
if (!(Get-AzResourceGroup -Tag $tag)) {
    New-AzResourceGroup -Name $ResourceGroupName -Location $region -Tag $tag
}

$VaultName  = "${ResourceGroupName}kv"

if (!(Get-AzKeyVault -VaultName $VaultName)) {
    $kv = New-AzKeyVault -VaultName $VaultName  `
        -ResourceGroupName $ResourceGroupName `
        -Location $region `
        -Sku Standard

    $VaultName  = "${ResourceGroupName}kv" 
}
Set-AzKeyVaultAccessPolicy -VaultName $VaultName  -UserPrincipalName $UserPrincipalName `
    -PermissionsToSecrets get,set,list `
    -PermissionsToCertificates create,get,list,import

$AutomationAccountName = "${ResourceGroupName}ac"
if (!(Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName -ErrorAction SilentlyContinue)) {
    New-AzAutomationAccount -Name $AutomationAccountName -Location $Region -ResourceGroupName $ResourceGroupName
}

$SpName  = "${ResourceGroupName}sp"
if (!(Get-AzADServicePrincipal -DisplayName $SpName)) {
    $UserSp = (az ad sp create-for-rbac --name $SpName  --create-cert --cert $SpName --keyvault $VaultName) | ConvertFrom-Json
    az keyvault secret download --name $SpName --vault-name $VaultName --encoding base64 --file inputCert.pfx
    openssl pkcs12 -in inputCert.pfx -out temp.pem -nodes -password pass:""
    Remove-Item .\inputCert.pfx -Force

    $CertName = "${SpName}Cert.pfx"
    $password = (openssl rand -base64 10)
    openssl pkcs12 -export -out $CertName -in temp.pem -password pass:"$password"
    Remove-Item .\temp.pem -Force

    Write-Host "$CertName Password: $password"

    $AutoPassword = ConvertTo-SecureString -String $password -AsPlainText -Force
    
    if (!(Get-AzAutomationCertificate -AutomationAccountName $AutomationAccountName `
        -Name $CertName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue)) {
        Write-Host "Creating new cert in automation account: $CertName"
        $Cert = New-AzAutomationCertificate -AutomationAccountName $AutomationAccountName `
            -Name $CertName `
            -Path "./$CertName" `
            -Password $AutoPassword `
            -ResourceGroupName $ResourceGroupName
    } else {
        Write-Host "Update existing cert in automation account: $CertName"
        $Cert = Set-AzAutomationCertificate -AutomationAccountName $AutomationAccountName `
            -Name $CertName `
            -Path "./$CertName" `
            -Password $AutoPassword `
            -ResourceGroupName $ResourceGroupName
    }
    
    Remove-Item "./$CertName" -Force

    $SubscriptionId = (Get-AzResourceGroup -Name $ResourceGroupName).ResourceId.Split('/')[2]
    
    $FieldValues = @{ 
        "SubscriptionId" = $SubscriptionId;
        "ApplicationId" = $UserSp.appId;
        "TenantId" = $UserSp.tenant;
        "CertificateThumbprint" = $Cert.Thumbprint;
    }

    New-AzAutomationConnection -Name $SpName `
        -ConnectionTypeName AzureServicePrincipal `
        -ConnectionFieldValues $FieldValues `
        -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $AutomationAccountName    
}

CreateVirtualNetworkIfNotExist -ResourceGroupName $ResourceGroupName -Region $region -Prefix "10.0"
CreateVirtualNetworkIfNotExist -ResourceGroupName $ResourceGroupName -Region $region2 -Prefix "10.1"

$AccountName = "${Region}${ResourceGroupName}"
if (!(Get-AzStorageAccount -ResourceGroupName $ResourceGroupName `
    -AccountName $AccountName `
    -ErrorAction SilentlyContinue)) {
    
    # Temporary add Cloud Shell ip to allow list.
    $pip = (Invoke-RestMethod -Uri 'https://api.ipify.org?format=json').ip

    New-AzStorageAccount -ResourceGroupName $ResourceGroupName `
        -AccountName $AccountName `
        -Location $Region `
        -Type Standard_LRS `
        -NetworkRuleSet ( @{ 
            bypass="Logging,Metrics";
            ipRules = (@{IPAddressOrRange=$pip;Action="allow"});
            defaultAction = "Deny"} )
} else {
    Write-Host "Storage Account $AccountName already exist."
}

EnableSubnetAccessToStorage -AccountName $AccountName -Region $Region -ResourceGroupName $ResourceGroupName
EnableSubnetAccessToStorage -AccountName $AccountName -Region $Region2 -ResourceGroupName $ResourceGroupName

$StorageContext = New-AzStorageContext -StorageAccountName $AccountName
$DeployContainerName = "deploy"

$lastErrorCount = $Error.Count
if (!(Get-AzStorageContainer -Name $DeployContainerName -Context $StorageContext `
    -ErrorAction SilentlyContinue)) {

    $skipNewStorage = $False
    if ($Error.Count -gt $lastErrorCount) {
            $lastErrorMessage = $Error[0].ToString()

            if ($lastErrorMessage.Contains("HTTP Status Code: 403")) {
                Write-Host "Container $DeployContainerName MAY already exist."
                $skipNewStorage = $True
            } else {
                throw $lastErrorMessage
                return
            }
    }

    if (!$skipNewStorage) {
        New-AzStorageContainer -Name $DeployContainerName -Context $StorageContext
    }
    
} else {
    Write-Host "Container $DeployContainerName already exist."
}
