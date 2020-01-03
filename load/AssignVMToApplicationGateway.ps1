param($ResourceGroupName, $StackName, $ApplicationGatewayStackName)

$ErrorActionPreference = "Stop"

$ApplicationGatewayName = "${ApplicationGatewayStackName}-agw"
$ApplicationGateway = Get-AzApplicationGateway `
    -Name $ApplicationGatewayName `
    -ResourceGroupName $ResourceGroupName 

$nic = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name "${StackName}-nic"

$ApplicationGatewayBackendPoolName = "${ApplicationGatewayStackName}-backendpool"
Add-AzApplicationGatewayBackendAddressPool -ApplicationGateway $ApplicationGateway `
    -Name $ApplicationGatewayBackendPoolName `
    -BackendIPConfigurationIds $nic.IpConfigurations.Id