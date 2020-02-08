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

    LogMessage -Message "Installing dotnet core" -LogFileName $logFileName
    if (!(Test-Path "C:\tools")) {
        New-Item -Path C:\tools -ItemType Directory
    }
    
    Invoke-WebRequest -Uri https://download.visualstudio.microsoft.com/download/pr/854ca330-4414-4141-9be8-5da3c4be8d04/3792eafd60099b3050313f2edfd31805/dotnet-sdk-3.1.101-win-x64.exe -UseBasicParsing -OutFile C:\tools\dotnet-sdk-3.1.101-win-x64.exe
    Push-Location C:\tools

    .\dotnet-sdk-3.1.101-win-x64.exe /install /norestart /quiet /log "C:\tools\dotnet-sdk-3.1.101-win-x64.log"
    Pop-Location
    LogMessage -Message "Done installing dotnet core" -LogFileName $logFileName

    # Display dotnet version
    LogMessage -Message (dotnet --version) -LogFileName $logFileName
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

LogMessage -Message "Installing OpenSSH Server" -LogFileName $logFileName
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

Start-Service sshd
# OPTIONAL but recommended:
Set-Service -Name sshd -StartupType 'Automatic'
# Confirm the Firewall rule is configured. It should be created automatically by setup. 
Get-NetFirewallRule -Name *ssh*
# There should be a firewall rule named "OpenSSH-Server-In-TCP", which should be enabled
# If the firewall does not exist, create one
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
LogMessage -Message "Done installing OpenSSH Server" -LogFileName $logFileName

LogMessage -Message "Setting up powershell as the default for SSH" -LogFileName $logFileName
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force
LogMessage -Message "Done setting up powershell as the default for SSH" -LogFileName $logFileName