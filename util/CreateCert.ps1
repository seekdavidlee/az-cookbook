param($DomainName)

Push-Location ..\

$path = ".cert"
If(!(Test-Path $path))
{
    New-Item -ItemType Directory -Force -Path $path
}

Push-Location $path
$command = "openssl req -x509" `
    + " -sha256 -nodes -days 365 -newkey rsa:2048" `
    + " -keyout privateKey.key -out $DomainName.crt" `
    + " -subj ('/CN=$DomainName/O=David Lee/C=US')"

Invoke-Expression $command
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error"
    return
}

$command = "openssl pkcs12 -export -out $DomainName.pfx -inkey privateKey.key -in $DomainName.crt"
Invoke-Expression $command
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error"
    return
}

$command = "download $DomainName.pfx"
Invoke-Expression $command

Pop-Location
Pop-Location