param(
    $RootDirectory,
    $ResourceGroupName, 
    $StorageAccountName)

$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName `
    -Name $StorageAccountName).Value[0]

$ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $storageAccountKey

Set-AzStorageBlobContent -Container "deploy" `
    -File "$RootDirectory/vm/init/ConfigureServer.ps1" -Blob "ConfigureServer.ps1" `
    -Context $ctx