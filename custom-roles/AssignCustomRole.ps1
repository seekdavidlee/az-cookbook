param($User, $RoleName, $ResourceGroupName)

New-AzRoleAssignment -SignInName $User `
    -RoleDefinitionName $RoleName `
    -ResourceGroupName $ResourceGroupName
