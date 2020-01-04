param($ResourceGroupName, $Name, $ImageName)

$registry = Get-AzContainerRegistry -ResourceGroupName $ResourceGroupName -Name $Name
$creds = Get-AzContainerRegistryCredential -Registry $registry
$password = ConvertTo-SecureString $creds.Password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($creds.Username, $password)

$Image = "$Name.azurecr.io/${ImageName}:latest" 
Write-Host "Image name: $Image"
New-AzContainerGroup -ResourceGroupName $ResourceGroupName -Name $ImageName -Image $Image -OsType Windows -DnsNameLabel $ImageName -RegistryCredential $cred
