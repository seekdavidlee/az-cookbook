param(
    $ConnectionName, 
    $Region, 
    $ResourceGroupName, 
    $StackName)

$ErrorActionPreference = "Stop"

$Conn = Get-AutomationConnection -Name $ConnectionName

Connect-AzAccount -ServicePrincipal -Tenant $Conn.TenantId `
    -ApplicationId $Conn.ApplicationId -CertificateThumbprint $Conn.CertificateThumbprint

$tag = @{ "purpose"="system-operations" }
$OpsResourceGroupName = (Get-AzResourceGroup -Tag $tag).ResourceGroupName

if (!$OpsResourceGroupName) {
    throw "Unable to find valid resource group"
    return
}

$VirtualNetworkName = "$Region-${OpsResourceGroupName}vn"

$Tags = @{"stack-name"="${StackName}"}
$virtualNetwork = Get-AzVirtualNetwork -Name $VirtualNetworkName

# This is just my covention, my subnets are always /24, so I can just add one more. However, if a subnet in between 
# gets removed, then this logic will not work.
Write-Host "Creating subnet for application gateway..."
$count = (Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $virtualNetwork).Count + 1

# We need to associate this new subnet to the application gateway we are creating later.
$ApplicationGatewaySubnetName = "${StackName}-frontend"

# Don't create the subnet if it already exist.
if (!(Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $ApplicationGatewaySubnetName -ErrorAction SilentlyContinue)) {
    Add-AzVirtualNetworkSubnetConfig -Name $ApplicationGatewaySubnetName -VirtualNetwork $virtualNetwork -AddressPrefix "10.0.$count.0/24"
    $virtualNetwork | Set-AzVirtualNetwork
    Write-Warning "Added Subnet $ApplicationGatewaySubnetName to Virtual network."

} else {
    Write-Warning "Subnet $ApplicationGatewaySubnetName already exist."    
}

$subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $virtualNetwork -Name $ApplicationGatewaySubnetName

if (!$subnet) {
    Write-Warning "Still creating subnet... Please try again later!"
    return
}

$PublicIPName = "${StackName}-pip"
Write-Host "Creating Public IP $PublicIPName"
$PublicIP = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Location $Region -Name $PublicIPName `
    -AllocationMethod Static -IdleTimeoutInMinutes 4 -Tag $Tags -DomainNameLabel $StackName -Sku Standard

$ApplicationGatewayIPConfigName = "${StackName}-ipconfig"
Write-Host "Creating IP Config $ApplicationGatewayIPConfigName"
$ApplicationGatewayIPConfig = New-AzApplicationGatewayIPConfiguration `
    -Name $ApplicationGatewayIPConfigName `
    -Subnet $subnet

$ApplicationGatewayFrontendIPConfigName = "${StackName}-frontendipconfig"
$ApplicationGatewayFrontendIPConfig = New-AzApplicationGatewayFrontendIPConfig `
    -Name $ApplicationGatewayFrontendIPConfigName `
    -PublicIPAddress $PublicIP

$ApplicationGatewayFrontendPortName = "${StackName}-frontendport"
Write-Host "Creating Frontend port $ApplicationGatewayFrontendPortName"    
$ApplicationGatewayFrontendPort = New-AzApplicationGatewayFrontendPort `
    -Name $ApplicationGatewayFrontendPortName `
    -Port 80

$ApplicationGatewayBackendPoolName = "${StackName}-backendpool" 
Write-Host "Creating backendpool $ApplicationGatewayBackendPoolName"     
$ApplicationGatewayBackendPool = New-AzApplicationGatewayBackendAddressPool `
    -Name $ApplicationGatewayBackendPoolName

$ApplicationGatewayBackendPoolSettingsName = "${StackName}-backendpoolsettings"
Write-Host "Creating backendpool settings $ApplicationGatewayBackendPoolSettingsName"  
$ApplicationGatewayBackendPoolSetting = New-AzApplicationGatewayBackendHttpSetting `
    -Name $ApplicationGatewayBackendPoolSettingsName `
    -Port 80 `
    -Protocol Http `
    -CookieBasedAffinity Enabled `
    -RequestTimeout 30

# Create the listener and add a rule
$ApplicationGatewayListenerName = "${StackName}-listener"
Write-Host "Creating listener $ApplicationGatewayListenerName"   
$ApplicationGatewayListener = New-AzApplicationGatewayHttpListener `
  -Name $ApplicationGatewayListenerName `
  -Protocol Http `
  -FrontendIPConfiguration $ApplicationGatewayFrontendIPConfig `
  -FrontendPort $ApplicationGatewayFrontendPort

$ApplicationGatewayFrontendRuleName = "${StackName}-frontendrule" 
$ApplicationGatewayFrontendRule = New-AzApplicationGatewayRequestRoutingRule `
  -Name $ApplicationGatewayFrontendRuleName `
  -RuleType Basic `
  -HttpListener $ApplicationGatewayListener `
  -BackendAddressPool $ApplicationGatewayBackendPool `
  -BackendHttpSettings $ApplicationGatewayBackendPoolSetting

$sku = New-AzApplicationGatewaySku `
  -Name Standard_v2 `
  -Tier Standard_v2 `
  -Capacity 2

$ApplicationGatewayName = "${StackName}-agw"
Write-Host "Creating application gateway $ApplicationGatewayName"  
New-AzApplicationGateway `
  -Name $ApplicationGatewayName `
  -ResourceGroupName $ResourceGroupName `
  -Location $Region `
  -BackendAddressPools $ApplicationGatewayBackendPool `
  -BackendHttpSettingsCollection $ApplicationGatewayBackendPoolSetting `
  -FrontendIpConfigurations $ApplicationGatewayFrontendIPConfig `
  -GatewayIpConfigurations $ApplicationGatewayIPConfig `
  -FrontendPorts $ApplicationGatewayFrontendPort `
  -HttpListeners $ApplicationGatewayListener `
  -RequestRoutingRules $ApplicationGatewayFrontendRule `
  -Tag $Tags `
  -Sku $sku