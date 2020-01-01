param([switch] $Web, [switch] $DotNetCore)

if ($Web) {
    Add-WindowsFeature Web-Server
    Add-Content -Path "C:\inetpub\wwwroot\Default.htm" -Value "<html><b>Hello World from $($env:computername)!</b></html>"
}

if ($DotNetCore) {
    New-Item -Path C:\tools -ItemType Directory
    Invoke-WebRequest -Uri https://dot.net/v1/dotnet-install.ps1 -UseBasicParsing -OutFile C:\tools\dotnet-install.ps1
    Push-Location C:\tools
    .\dotnet-install.ps1 -Channel LTS
    Pop-Location
}