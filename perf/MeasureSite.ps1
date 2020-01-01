param($Uri, $Count, $DelayInSeconds)

$responses = @()
$measures = @()

for($i = 0; $i -lt $Count; $i++) {
    $num = $i + 1
    Write-Host "Processing $num of $Count"
    
    # Set DisableKeepAlive, otherwise our Azure Load Balancer would not perform a round-robin way of distributing our load.
    # https://blogs.msdn.microsoft.com/cie/2017/04/19/how-to-fix-load-balancer-not-working-in-round-robin-fashion-for-your-cloud-service/

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
