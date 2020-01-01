param($ResourceGroupName, $StackName, $VMSize, $WindowsSkuName, $KeyVaultName, $StorageAccountName, $StackPrefix, [switch] $Web, [switch] $DotNetCore, [switch]$IsPrivate)

$ErrorActionPreference = "Stop"

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

$password = (openssl rand -base64 32)

if ($KeyVaultName) {
    Write-Host "Password will be stored in Azure Key Vault"    
} else {
    Write-Host "One-time password display (please store in secure location): $password"
}

$VMLocalAdminUser = "LocalAdminUser"
$VMLocalAdminSecurePassword = ConvertTo-SecureString $password -AsPlainText -Force
$LocationName = (Get-AzResourceGroup -Name $ResourceGroupName).Location

$VMName = $ComputerName
$Tags = @{"stack-name"="${StackName}-${prefix}"}
$VnetName = "${StackName}-vnet"
$SubnetName = "${StackName}-frontend"
$subnet = (Get-AzVirtualNetwork -Name $VnetName).Subnets | ? { $_.Name -eq $SubnetName }

if (!$IsPrivate) {
    $PublicIPName = "${VMName}-pip"
    Write-Host "Creating Public IP $PublicIPName"
    
    $PublicIP = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Location $LocationName -Name $PublicIPName `
        -AllocationMethod Dynamic -IdleTimeoutInMinutes 4 -Tag $Tags -DomainNameLabel $VMName
} else {
    Write-Host "Did not allocate public ip because this is a private vm"
}

$NSG = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Location $LocationName -Name "${VMName}-nsg" -Tag $Tags

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
    $NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName `
        -SubnetId $subnet.Id `
        -Tag $Tags `
        -PublicIpAddressId $PublicIP.Id `
        -NetworkSecurityGroupId $NSG.Id
} else {
    $NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName `
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
New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine -Verbose

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
    "targetResourceId" = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName).Id
}

New-AzureRmResource -ResourceId ("/subscriptions/{0}/resourceGroups/{1}/providers/microsoft.devtestlab/schedules/shutdown-computevm-{2}" -f (Get-AzureRmContext).Subscription.Id, $ResourceGroupName, $VMName) -Location $LocationName -Properties $properties -Force

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
        $args += "-Web "
    }

    if ($DotNetCore) {
        $args += "-DotNetCore"
    }

    Set-AzVMCustomScriptExtension -ResourceGroupName $ResourceGroupName `
        -Name "ConfigureServer" `
        -VMName $VMName `
        -Location $LocationName `
        -StorageAccountKey $storageAccountKey `
        -ContainerName "deploy" `
        -StorageAccountName $StorageAccountName `
        -FileName "ConfigureServer.ps1" `
        -RunFile "ConfigureServer.ps1" `
        -Argument $args
}

