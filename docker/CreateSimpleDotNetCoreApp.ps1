param(
    [Parameter(Mandatory = $true)][string]$DockerFilePath, 
    [Parameter(Mandatory = $true)][string]$Name)

$path = (Get-Location).Path + "\$DockerFilePath\Dockerfile"
$dockerIgnorePath = (Get-Location).Path + "\$DockerFilePath\.dockerignore"

if (!(Test-Path $path -PathType Leaf)) {
    Write-Warning "Unable to locate docker file at $path"
    return
}

Push-Location $home
if (!(Test-Path .\.wd)) {
    New-Item -ItemType Directory -Force -Path .\.wd
}

if (!(Test-Path ".\.wd\$Name")) {
    Push-Location .\.wd

    $f = get-date -f yyyy-MM-dd-HHss
    New-Item -ItemType Directory -Force -Path .\$f
    Push-Location .\$f

    dotnet new webapp --name $Name
    Push-Location $Name
    $content = Get-Content -Path $path
    $content = $content.Replace("%ProjectName%", $Name)
    Set-Content -Path .\Dockerfile -Value $content
    Copy-Item $dockerIgnorePath  .\
    docker build -t $Name .
    Pop-Location
    Pop-Location
    Pop-Location
}
Pop-Location

docker run -d -p 8080:80 -d --name $Name $Name

Write-Host "$Name running. See http://localhost:8080"