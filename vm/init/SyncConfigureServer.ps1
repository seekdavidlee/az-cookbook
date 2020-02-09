param(
    $RootDirectory,
    $ResourceGroupName)

$StorageAccountName = (Get-AzStorageAccount -ResourceGroupName $ResourceGroupName).StorageAccountName
$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName `
    -Name $StorageAccountName).Value[0]

$ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $storageAccountKey

# Temporary add Cloud Shell ip to allow list.
$ip = (Invoke-RestMethod -Uri 'https://api.ipify.org?format=json').ip

Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -AccountName $StorageAccountName -IPAddressOrRange $ip

$status = Set-AzStorageBlobContent -Container "deploy" `
    -File "$RootDirectory/vm/init/ConfigureServer.ps1" -Blob "ConfigureServer.ps1" `
    -Context $ctx `
    --ErrorAction SilentlyContinue `
    -Force

$status

# Remove Cloud Shell ip from allow list since we are done.
Remove-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -AccountName $StorageAccountName -IPAddressOrRange $ip