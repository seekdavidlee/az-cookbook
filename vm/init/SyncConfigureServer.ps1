param(
    $RootDirectory,
    $ResourceGroupName, 
    $StorageAccountName)

$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName `
    -Name $StorageAccountName).Value[0]

$ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $storageAccountKey

# Temporary add Cloud Shell ip to allow list.
$ip = (Invoke-RestMethod -Uri 'https://api.ipify.org?format=json').ip

Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -AccountName $StorageAccountName -IPAddressOrRange $ip

for($i = 0; $i -lt 5; $i++) {

    Set-AzStorageBlobContent -Container "deploy" `
    -File "$RootDirectory/vm/init/ConfigureServer.ps1" -Blob "ConfigureServer.ps1" `
    -Context $ctx `
    -Force
    
    if ($Error -and $Error[$Error.Count - 1].ToString().Contains("HTTP Status Code: 403")) {
        Write-Host "Retry $i"
        Start-Sleep -Seconds 3
    } else {
        Write-Host "Done!"
        break
    }
}

# Remove Cloud Shell ip from allow list since we are done.
Remove-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -AccountName $StorageAccountName -IPAddressOrRange $ip