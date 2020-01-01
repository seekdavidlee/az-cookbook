param($ResourceGroupName, $StackName, $LoadBalancerName)

$ErrorActionPreference = "Stop"

$lb = Get-AzLoadBalancer -ResourceGroupName $ResourceGroupName -Name "${LoadBalancerName}-LoadBalancer"
$nic = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name "${StackName}-nic"
$nic | Set-AzNetworkInterfaceIpConfig -Name "ipconfig1" -LoadBalancerBackendAddressPool $lb.BackendAddressPools[0] | Set-AzNetworkInterface