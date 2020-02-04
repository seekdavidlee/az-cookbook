param($ResourceGroupName, $StackName, $ConnectionName)

$ErrorActionPreference = "Stop"

$Conn = Get-AutomationConnection -Name $ConnectionName

Connect-AzAccount -ServicePrincipal -Tenant $Conn.TenantId `
    -ApplicationId $Conn.ApplicationId -CertificateThumbprint $Conn.CertificateThumbprint

$Tags = @{"stack-name"="${StackName}"}
$LocationName = (Get-AzResourceGroup -Name $ResourceGroupName).Location

$PublicIPName = "${StackName}-pip"
Write-Host "Creating Public IP $PublicIPName"

# Standard sku load balancer must reference Standard Sku public ip
# Standard sku public ip must have allocation method set to static
$PublicIP = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Location $LocationName -Name $PublicIPName `
    -AllocationMethod Static -IdleTimeoutInMinutes 4 -Tag $Tags -DomainNameLabel $StackName -Sku Standard

$feip = New-AzLoadBalancerFrontendIpConfig -Name "${StackName}-FrontEndPool" -PublicIpAddress $PublicIP  
$bepool = New-AzLoadBalancerBackendAddressPoolConfig -Name "${StackName}-BackEndPool"

$probe = New-AzLoadBalancerProbeConfig `
    -Name "${StackName}-HealthProbe" `
    -Protocol Http -Port 80 `
    -RequestPath / -IntervalInSeconds 60 -ProbeCount 3

 $rule = New-AzLoadBalancerRuleConfig `
    -Name "${StackName}-LoadBalancerRuleWeb" -Protocol Tcp `
    -Probe $probe -FrontendPort 80 -BackendPort 80 `
    -FrontendIpConfiguration $feip `
    -BackendAddressPool $bePool

$lb = New-AzLoadBalancer `
    -Tag $Tags `
    -ResourceGroupName $ResourceGroupName `
    -Name "${StackName}-LoadBalancer" `
    -SKU Basic `
    -Location $LocationName `
    -FrontendIpConfiguration $feip `
    -BackendAddressPool $bepool `
    -Probe $probe `
    -LoadBalancingRule $rule    