param(
    $ConnectionName,
    $ResourceGroupName, 
    $StackName, 
    $VMSize, 
    $WindowsSkuName, 
    $StackPrefix, 
    $Region,
    [switch] $Web, 
    [switch] $DotNetCore, 
    [switch] $Git, 
    [switch] $Backend,
    [switch] $IsPrivate)

$ErrorActionPreference = "Stop"

$Conn = Get-AutomationConnection -Name $ConnectionName

Connect-AzAccount -ServicePrincipal -Tenant $Conn.TenantId `
    -ApplicationId $Conn.ApplicationId -CertificateThumbprint $Conn.CertificateThumbprint

$tag = @{ "purpose"="system-operations" }
$OpsResourceGroupName = (Get-AzResourceGroup -Tag $tag).ResourceGroupName

if (!$OpsResourceGroupName) {
    throw "Unable to find valid resource group"
    return
}

if (!(Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $ResourceGroupName -Location $Region
}

$KeyVaultName = (Get-AzResource -ResourceGroupName $OpsResourceGroupName -ResourceType Microsoft.KeyVault/vaults).Name
$StorageAccountName = (Get-AzResource -ResourceGroupName $OpsResourceGroupName -ResourceType Microsoft.Storage/storageAccounts).Name

if ($StackPrefix) {
    Write-Host "Using Prefix $StackPrefix"
    $prefix = $StackPrefix    
} else {
    $count = (Get-AzVM -ResourceGroupName $ResourceGroupName).Count
    $count = $count + 1
    $prefix = ([string]$count).PadLeft(3,"0")
}

if ($Web) {
    $ComputerName = "${StackName}-web${prefix}"    
} else {
    $ComputerName = "${StackName}-vm${prefix}" 
}

$results = (Get-AzVM -ResourceGroupName $ResourceGroupName) | Where { $_.Name -eq $ComputerName } | measure
if ($results.Count -eq 1) {
    Write-Warning "$ComputerName already exist!"
    return
}

Add-Type -AssemblyName "System.Web"
$password = [System.Web.Security.Membership]::GeneratePassword(24, 0)

if ($KeyVaultName) {
    Write-Host "Password will be stored in Azure Key Vault"    
} else {
    Write-Host "One-time password display (please store in secure location): $password"
}

$VMLocalAdminUser = "LocalAdminUser"
$VMLocalAdminSecurePassword = ConvertTo-SecureString $password -AsPlainText -Force

$VMName = $ComputerName
$Tags = @{"stack-name"="${StackName}-${prefix}"}
$VnetName = "$Region-${ResourceGroupName}vn"

if ($Backend) {
    $SubnetName = "$Region-backend-subnet"
}else {
    $SubnetName = "$Region-frontend-subnet"
}

$subnet = (Get-AzVirtualNetwork -Name $VnetName).Subnets | ? { $_.Name -eq $SubnetName }

if (!$IsPrivate) {
    $PublicIPName = "${VMName}-pip"
    Write-Host "Creating Public IP $PublicIPName"
    
    $PublicIP = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Location $Region -Name $PublicIPName `
        -AllocationMethod Dynamic -IdleTimeoutInMinutes 4 -Tag $Tags -DomainNameLabel $VMName
} else {
    Write-Host "Did not allocate public ip because this is a private vm"
}

$NSG = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Location $Region -Name "${VMName}-nsg" -Tag $Tags

$IPConfigName = "${VMName}-ipconfig"

Write-Host "Creating IP Config $IPConfigName"

if (!$IsPrivate) {
    $IPConfig = New-AzNetworkInterfaceIpConfig -Name $IPConfigName -Subnet $subnet -PublicIpAddress $PublicIP -Primary
} else {
    $IPConfig = New-AzNetworkInterfaceIpConfig -Name $IPConfigName -Subnet $subnet
}

$Port = "80"
$Priority = 300
$NSG | Add-AzNetworkSecurityRuleConfig -Name "Allow_$Port" -Protocol Tcp -Direction Inbound `
    -Priority $Priority -SourceAddressPrefix * -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange $Port -Access Allow | Set-AzNetworkSecurityGroup

$NICName = "${ComputerName}-nic"

Write-Host "Creating NIC $NICName for VM"

if (!$IsPrivate) {
    $NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $Region `
        -SubnetId $subnet.Id `
        -Tag $Tags `
        -PublicIpAddressId $PublicIP.Id `
        -NetworkSecurityGroupId $NSG.Id
} else {
    $NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $Region `
        -SubnetId $subnet.Id `
        -Tag $Tags `
        -NetworkSecurityGroupId $NSG.Id
}

$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);

$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize -Tags $Tags
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -Name "${ComputerName}-osdisk" -CreateOption FromImage `
    -StorageAccountType "Standard_LRS" -DiskSizeInGB 40 -Caching ReadWrite
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus $WindowsSkuName -Version latest
$VirtualMachine | Set-AzVMBootDiagnostic -Enable -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName

Write-Host "Creating VM $VMName..."
New-AzVM -ResourceGroupName $ResourceGroupName -Location $Region -VM $VirtualMachine -Verbose

Write-Host "Setting up auto-shutdown schedule for VM"
$shutdown_time = "2000"
$shutdown_timezone = "Central Standard Time"

$properties = @{
    "status" = "Enabled";
    "taskType" = "ComputeVmShutdownTask";
    "dailyRecurrence" = @{"time" = $shutdown_time };
    "timeZoneId" = $shutdown_timezone;
    "notificationSettings" = @{
        "status" = "Disabled";
        "timeInMinutes" = 30
    }
    "targetResourceId" = (Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName).Id
}

New-AzResource -ResourceId ("/subscriptions/{0}/resourceGroups/{1}/providers/microsoft.devtestlab/schedules/shutdown-computevm-{2}" -f (Get-AzContext).Subscription.Id, $ResourceGroupName, $VMName) -Location $Region -Properties $properties -Force

if ($KeyVaultName) {

    Write-Host "Storing password in Azure Key Vault $KeyVaultName"
    # Let's not display the secret (password), and keep it inside the key vault.
    Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $VMName -SecretValue $VMLocalAdminSecurePassword | Out-Null

    Write-Host "Enabling disk encryption..."
    $keyVault = Get-AzKeyVault -VaultName $KeyVaultName -ResourceGroupName $ResourceGroupName

    Set-AzVMDiskEncryptionExtension -ResourceGroupName $ResourceGroupName -VMName $VMName `
        -DiskEncryptionKeyVaultUrl $keyVault.VaultUri -DiskEncryptionKeyVaultId $keyVault.ResourceId -Force
}

if ($Web -or $DotNetCore) {
    Write-Host "Configuring $VMName..."

    $storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName `
        -Name $StorageAccountName).Value[0]

    $args = ""

    if ($Web) {
        $args += " -Web"
    }

    if ($DotNetCore) {
        $args += " -DotNetCore"
    }

    if ($Git) {
        $args += " -Git"
    }    

    Set-AzVMCustomScriptExtension -ResourceGroupName $ResourceGroupName `
        -Name "ConfigureServer" `
        -VMName $VMName `
        -Location $Region `
        -StorageAccountKey $storageAccountKey `
        -ContainerName "deploy" `
        -StorageAccountName $StorageAccountName `
        -FileName "ConfigureServer.ps1" `
        -RunFile "ConfigureServer.ps1" `
        -Argument $args
}

