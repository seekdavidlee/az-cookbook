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
    try {
        Set-AzStorageBlobContent -Container "deploy" `
        -File "$RootDirectory/vm/init/ConfigureServer.ps1" -Blob "ConfigureServer.ps1" `
        -Context $ctx `
        -Force
        break
    }
    catch {
        $ex = $_
        $ex.Exception
        if ($ex.Exception.Contains("not authorized")) {
            Write-Host "Try $i"
            Start-Sleep -Seconds 3
        } else {
            throw
        }
    }
}

# Remove Cloud Shell ip from allow list since we are done.
Remove-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -AccountName $StorageAccountName -IPAddressOrRange $ip