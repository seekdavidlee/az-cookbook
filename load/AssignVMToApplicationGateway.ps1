param($VNetName, $ResourceGroupName, $StackName, $ApplicationGatewayName)

$ErrorActionPreference = "Stop"

$ApplicationGateway = Get-AzApplicationGateway `
    -Name $ApplicationGatewayName `
    -ResourceGroupName $ResourceGroupName 

$nic = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name "${StackName}-nic"

$ApplicationGatewayBackendPoolName = "${StackName}-backendpool" 
Set-AzureRmApplicationGatewayBackendAddressPool -ApplicationGateway $ApplicationGateway `
    -Name $ApplicationGatewayBackendPoolName `
    -BackendIPAddresses $nic.Properties.IpConfigurations[0].Id