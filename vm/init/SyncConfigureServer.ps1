param(
    $ResourceGroupName, 
    $StorageAccountName)

$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName `
    -Name $StorageAccountName).Value[0]

$ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $storageAccountKey

Set-AzureStorageBlobContent -Container "deploy" `
    -File ".\ConfigureServer.ps1" -Blob "ConfigureServer.ps1" `
    -Context $ctx