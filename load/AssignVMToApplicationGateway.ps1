param($ResourceGroupName, $StackName, $ApplicationGatewayStackName)

$ErrorActionPreference = "Stop"

$ApplicationGatewayName = "${ApplicationGatewayStackName}-agw"
$ApplicationGateway = Get-AzApplicationGateway `
    -Name $ApplicationGatewayName `
    -ResourceGroupName $ResourceGroupName 

$nic = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name "${StackName}-nic"

$ApplicationGatewayBackendPoolName = "${ApplicationGatewayStackName}-backendpool"
$backendpool = (Get-AzApplicationGatewayBackendAddressPool -Name $ApplicationGatewayBackendPoolName -ApplicationGateway $ApplicationGateway)

# https://github.com/Azure/azure-rest-api-specs/issues/7475
$nic.IpConfigurations[0].ApplicationGatewayBackendAddressPools += $backendpool
$nic | Set-AzNetworkInterface