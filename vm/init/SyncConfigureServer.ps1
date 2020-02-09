param($RootDirectory)

$tag = @{ "purpose"="system-operations" }
$ResourceGroupName = (Get-AzResourceGroup -Tag $tag).ResourceGroupName

if (!$ResourceGroupName) {
    throw "Unable to find valid resource group"
}

$StorageAccountName = (Get-AzStorageAccount -ResourceGroupName $ResourceGroupName).StorageAccountName
$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName `
    -Name $StorageAccountName).Value[0]

$ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $storageAccountKey

# Temporary add Cloud Shell ip to allow list.
$ip = (Invoke-RestMethod -Uri 'https://api.ipify.org?format=json').ip

$lastErrorCount = $Error.Count

Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName `
    -AccountName $StorageAccountName `
    -IPAddressOrRange $ip  

if ($Error.Count -gt $lastErrorCount) {
    $lastErrorMessage = $Error[0].ToString()
    if (!$lastErrorMessage.Contains("Values for request parameters are invalid")) {
        throw $lastErrorMessage
    }
}

Write-Host "Root Directory: $RootDirectory"

$lastErrorCount = $Error.Count

for($i = 0; $i -lt 8; $i++) {

    Set-AzStorageBlobContent -Container "deploy" `
        -File "$RootDirectory/vm/init/ConfigureServer.ps1" -Blob "ConfigureServer.ps1" `
        -Context $ctx `
        -Force

    if ($Error.Count -gt $lastErrorCount) {

        $lastErrorMessage = $Error[0].ToString()
        if ($lastErrorMessage.Contains("HTTP Status Code: 403")) {
            $lastErrorCount = $Error.Count
            Write-Host "Retry $i"
            # Increment wait by additional seconds
            $wait = $i + 3
            Write-Host "Waiting $wait seconds"
            Start-Sleep -Seconds $wait
        } else {
            throw $lastErrorMessage
        }
    } else {
        Write-Host "Successfully uploaded ConfigureServer.ps1"
        break
    }
}

# Remove Cloud Shell ip from allow list since we are done.
Remove-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -AccountName $StorageAccountName -IPAddressOrRange $ip

$Error.Clear()