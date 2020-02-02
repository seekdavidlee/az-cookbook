param(
	[Parameter(Mandatory=$true)][String[]] $ScriptPaths, 
	[Parameter(Mandatory=$true)]$AutomationAccountName, 
	[Parameter(Mandatory=$true)]$ResourceGroupName)

$ErrorActionPreference = "Stop"

$ScriptPaths | ForEach-Object {
	
	$ScriptPath = $_
	
	$RunbookName = $ScriptPath.Split('/', $ScriptPath.Length - 1)

	Write-Host "Processing $RunbookName"

	Import-AzureRMAutomationRunbook -Name $RunbookName `
		-Path $ScriptPath `
		-ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName `
		-Type PowerShell

	Write-Host "$RunbookName is synced"
}
