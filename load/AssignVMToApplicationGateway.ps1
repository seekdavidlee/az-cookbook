param($ResourceGroupName, $StackName, $ApplicationGatewayStackName)

$ErrorActionPreference = "Stop"

$ApplicationGatewayName = "${ApplicationGatewayStackName}-agw"
$ApplicationGateway = Get-AzApplicationGateway `
    -Name $ApplicationGatewayName `
    -ResourceGroupName $ResourceGroupName 

$nic = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name "${StackName}-nic"

$ApplicationGatewayBackendPoolName = "${ApplicationGatewayStackName}-backendpool"

$ipConfig = New-Object -TypeName Microsoft.Azure.Commands.Network.Models.PSNetworkInterfaceIPConfiguration
$ipConfig.Id = $nic.IpConfigurations.Id
$ipConfig.LoadBalancerBackendAddressPools = @()
$ipConfig.ApplicationGatewayBackendAddressPools = @()
$ipConfig.LoadBalancerInboundNatRules = @()
$ipConfig.ApplicationSecurityGroups = @()

if ($ApplicationGateway.BackendAddressPools.BackendIpConfigurations -is [array]) {
    Write-Host "Adding new ip config to existing array"
    $ApplicationGateway.BackendAddressPools.BackendIpConfigurations += $ipConfig
} else {
    Write-Host "Converting property to array and adding new ip config to array property"
    $ApplicationGateway.BackendAddressPools.BackendIpConfigurations = @($ApplicationGateway.BackendAddressPools.BackendIpConfigurations, $ipConfig)
}

"Updating application gateway"
Set-AzApplicationGateway -ApplicationGateway $ApplicationGateway