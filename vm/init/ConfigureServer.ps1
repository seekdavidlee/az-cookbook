param([switch] $Web, [switch] $DotNetCore, [switch] $Git)

if ($Web) {
    Add-WindowsFeature Web-Server
    Add-Content -Path "C:\inetpub\wwwroot\Default.htm" -Value "<html><head><title>Hello World</title><body><b>Hello World from $($env:computername)!</b></body></html>"
}

if ($DotNetCore) {
    if (!Test-Path "C:\tools") {
        New-Item -Path C:\tools -ItemType Directory
    }
    Invoke-WebRequest -Uri https://dot.net/v1/dotnet-install.ps1 -UseBasicParsing -OutFile C:\tools\dotnet-install.ps1
    Push-Location C:\tools
    .\dotnet-install.ps1 -Channel LTS
    Pop-Location
}

if ($Git) {
    if (!Test-Path "C:\tools") {
        New-Item -Path C:\tools -ItemType Directory
    }
    Invoke-WebRequest -Uri https://github.com/git-for-windows/git/releases/download/v2.25.0.windows.1/Git-2.25.0-64-bit.exe -OutFile C:\tools\Git-2.25.0-64-bit.exe
    Push-Location C:\tools
    .\Git-2.25.0-64-bit.exe /SILENT
    Pop-Location
}