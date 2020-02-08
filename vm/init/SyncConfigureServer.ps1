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

$lastErrorCount = $Error.Count
for($i = 0; $i -lt 5; $i++) {

    try {
        Set-AzStorageBlobContent -Container "deploy" `
            -File "$RootDirectory/vm/init/ConfigureServer.ps1" -Blob "ConfigureServer.ps1" `
            -Context $ctx `
            -Force
    }
    catch {
        if ($Error.Count -gt $lastErrorCount -and $Error[$Error.Count - 1].ToString().Contains("HTTP Status Code: 403")) {
            $lastErrorCount = $Error.Count
            Write-Host "Retry $i"
            # Increment wait by additional seconds
            $wait = $i + 3
            Write-Host "Waiting $wait seconds"
            Start-Sleep -Seconds $wait
        } else {
            Write-Host "Done!"
            break
        }
    }
}

# Remove Cloud Shell ip from allow list since we are done.
Remove-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -AccountName $StorageAccountName -IPAddressOrRange $ip