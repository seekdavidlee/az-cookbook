param($Uri, $Count, $DelayInSeconds)

$responses = @()
$measures = @()

for($i = 0; $i -lt $Count; $i++) {
    $num = $i + 1
    Write-Host "Processing $num of $Count"
    $measures += (Measure-Command { $responses += (Invoke-WebRequest -Uri $Uri -DisableKeepAlive) })

    if ($DelayInSeconds) {
        Start-Sleep -Seconds $DelayInSeconds
    }
    
}

$TotalMilliseconds = 0
for($i = 0; $i -lt $Count; $i++) {
    $measure =  $measures[$i]
    $response = $responses[$i]

    $response.Content
    $measure.TotalMilliseconds
    $TotalMilliseconds += $measure.TotalMilliseconds
}

$avg = $TotalMilliseconds / $Count
Write-Host "Average ms: $avg"
