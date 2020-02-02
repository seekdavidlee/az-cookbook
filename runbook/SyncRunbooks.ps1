param(
	[Parameter(Mandatory=$true)][String[]] $ScriptPaths, 
	[Parameter(Mandatory=$true)]$AutomationAccountName, 
	[Parameter(Mandatory=$true)]$ResourceGroupName)

$ErrorActionPreference = "Stop"

foreach ($ScriptPath in $ScriptPaths) {
	
	$paths =  $ScriptPath.Split('\')

	if ($paths.Length -lt 2) {
		$paths =  $ScriptPath.Split('/')
	}

	$RunbookName = $paths[$paths.Length - 1]

	Write-Host "Processing $RunbookName"

	Import-AzureRMAutomationRunbook -Name $RunbookName `
		-Path $ScriptPath `
		-ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName `
		-Type PowerShell `
		-Force

	Write-Host "$RunbookName is synced"
}
