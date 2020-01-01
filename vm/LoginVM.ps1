param($ResourceGroupName, $StackValue, $KeyVaultName)

$ErrorActionPreference = "Stop"

$VMLocalAdminUser = "LocalAdminUser"
$password = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $StackValue).SecretValueText
$VMLocalAdminSecurePassword = ConvertTo-SecureString $password -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword)

Write-Host "Logging in to VM..."

try {
    Enter-AzVM -name $StackValue -ResourceGroupName $ResourceGroupName -Credential $Credential
}
catch {
    $err = $_

    if ($err.Exception.Message.Contains("PowerShell remoting is not enabled.")) {
        Write-Host "Enabling PS Remoting on $StackValue..."
        Enable-AzVMPSRemoting -Name $StackValue -ResourceGroupName $ResourceGroupName -Protocol https -OsType Windows

        Enter-AzVM -name $StackValue -ResourceGroupName $ResourceGroupName -Credential $Credential
    } else {
        throw
    }
}

