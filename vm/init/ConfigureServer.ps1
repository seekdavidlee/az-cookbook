param([switch] $Web, [switch] $DotNetCore, [switch] $Git)

$logFileName = "$(get-date -f yyyy-MM-dd-HHmmss).log"
function LogMessage {
    param (
        $LogFileName,
        $Message
    )
    if (!(Test-Path "C:\logs")) {
        New-Item -Path C:\logs -ItemType Directory
    } 
    $Message = $(get-date -f yyyy-MM-dd-HHmmss) + " " + $Message

    $path = "C:\logs\$LogFileName"
    if (!(Test-Path $path)) {
        
        Set-Content -Path $path -Value $Message
    } else {
        Add-Content -Path $path -Value $Message
    }
}

LogMessage -Message "Installing components..." -LogFileName $logFileName

if ($Web) {
    LogMessage -Message "Installing web server" -LogFileName $logFileName
    Add-WindowsFeature Web-Server
    Add-Content -Path "C:\inetpub\wwwroot\Default.htm" -Value "<html><head><title>Hello World</title><body><b>Hello World from $($env:computername)!</b></body></html>"
    LogMessage -Message "Done installing web server" -LogFileName $logFileName
}

if ($DotNetCore) {

    LogMessage -Message "Installing dotnet" -LogFileName $logFileName
    if (!(Test-Path "C:\tools")) {
        New-Item -Path C:\tools -ItemType Directory
    }
    Invoke-WebRequest -Uri https://dot.net/v1/dotnet-install.ps1 -UseBasicParsing -OutFile C:\tools\dotnet-install.ps1
    Push-Location C:\tools
    .\dotnet-install.ps1 -Channel LTS
    Pop-Location
    LogMessage -Message "Done installing dotnet" -LogFileName $logFileName
}

if ($Git) {

    LogMessage -Message "Installing git" -LogFileName $logFileName
    if (!(Test-Path "C:\tools")) {
        New-Item -Path C:\tools -ItemType Directory
    }
    Invoke-WebRequest -Uri https://github.com/git-for-windows/git/releases/download/v2.25.0.windows.1/Git-2.25.0-64-bit.exe -OutFile C:\tools\Git-2.25.0-64-bit.exe
    Push-Location C:\tools
    .\Git-2.25.0-64-bit.exe /SILENT
    Pop-Location

    LogMessage -Message "Done installing git" -LogFileName $logFileName
}