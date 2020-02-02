param(
	[Parameter(Mandatory=$true)][String[]] $ScriptPaths, 
	[Parameter(Mandatory=$true)]$AutomationAccountName, 
	[Parameter(Mandatory=$true)]$ResourceGroupName)

$ScriptPaths | ForEach-Object {
	
	$ScriptPath = $_
	
	$RunbookName = [System.IO.Path]::GetFileName($ScriptPath)

	Write-Host "Processing $RunbookName"

	Import-AzureRMAutomationRunbook -Name $RunbookName `
		-Path $ScriptPath `
		-ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName `
		-Type PowerShell

	Write-Host "$RunbookName is synced"
}
