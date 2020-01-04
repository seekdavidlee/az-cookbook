param($ResourceGroupName, $Name)

$registry = Get-AzContainerRegistry -ResourceGroupName $ResourceGroupName -Name $Name
if (!$registry) {

    $Tags = @{"stack-name"="${Name}"}

    $registry = New-AzContainerRegistry -ResourceGroupName $ResourceGroupName -Name $Name -EnableAdminUser -Sku Basic -Tag $Tags
    $creds = Get-AzContainerRegistryCredential -Registry $registry
    $creds
}

