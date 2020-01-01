param($ResourceGroupName, $StackValue)
Write-Host "Disabling PS Remoting..."
Disable-AzVMPSRemoting -Name $StackValue -ResourceGroupName $ResourceGroupName