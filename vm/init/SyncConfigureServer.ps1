Set-AzureStorageBlobContent -Container "deploy" `
    -File ".\ConfigureServer.ps1" -Blob "ConfigureServer.ps1"