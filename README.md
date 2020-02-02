# az-cookbook
Welcome to cookbooks for managing resources in azure. The scripts are designed to run in the context of Azure Cloud Shell (https://shell.azure.com)

The scripts are categorized into 2 - one where the operations are quick and dirty and one for long running processes. Long running scripts cover multiple operations and are not suitable to run in the context of Cloud Shell where the security token can easily time out which means any next operation might error out if the previous operation took a while. Hence, we will be executing those scripts inside of Automation Account as a runbook. There is a SyncRunbooks.ps1 command to push your script changes to your Automation Runbook.
