param($ResourceGroupName, $StackValue)

$retryList = @()
Get-AzResource -ResourceGroupName $ResourceGroupName -TagValue $StackValue | ForEach-Object {
    $obj = $_.Id
    Write-Host "Removing ${obj}"

    try {
        Remove-AzResource -ResourceId $obj -Force -ErrorAction Stop
    }
    catch {
        Write-Host "Add to retry list $obj"
        $retryList += $obj
    }    
}

$retryList | ForEach-Object {

    $obj = $_
    Write-Host "Retry remove ${obj}"
    Remove-AzResource -ResourceId $obj -Force
}
