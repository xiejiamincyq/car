#requires -Version 7.0
# Observed 1 Hz context only; this does not prove continuous focus or release performance.
function ConvertTo-SoakUtc($Value) {
    if ($Value -is [DateTime]) { return $Value.ToUniversalTime() }
    if ($Value -is [DateTimeOffset]) { return $Value.UtcDateTime }
    return [DateTimeOffset]::Parse([string]$Value,[Globalization.CultureInfo]::InvariantCulture).UtcDateTime
}
function Get-SoakFrameKey([hashtable]$Sample) {
    foreach ($field in @('wall_seconds','runs','track','phase','speed','construction','overdrive')) {
        if (!$Sample.ContainsKey($field) -or $null -eq $Sample[$field]) { return '' }
    }
    if ($Sample.track -notin @('neon_coast','freight_harbor','storm_ridge','sunrise_express') -or
        $Sample.phase -ne 'RUNNING' -or $Sample.construction -isnot [bool] -or $Sample.overdrive -isnot [bool]) { return '' }
    try { $speed=[double]$Sample.speed;$wall=[double]$Sample.wall_seconds;$run=[double]$Sample.runs } catch { return '' }
    if (![double]::IsFinite($speed) -or $speed -le 0 -or ![double]::IsFinite($wall) -or $wall -lt 0 -or
        ![double]::IsFinite($run) -or $run -lt 1 -or $run -ne [Math]::Floor($run)) { return '' }
    $state = if ($Sample.overdrive) {'overdrive'} elseif ($Sample.construction) {'construction'} else {'driving'}
    return "$($Sample.track)/$state"
}
function Test-SoakFrameWindow([array]$Rows, [double]$Start, [double]$End, [string]$Key) {
    if (![double]::IsFinite($Start) -or ![double]::IsFinite($End) -or $Start -lt 0 -or $End -le $Start -or !$Key) { return $false }
    $finite=@($Rows | Where-Object { [double]::IsFinite([double]$_.wall_seconds) })
    $left=-1;$right=-1
    for($i=0;$i -lt $finite.Count;$i++) {
        if($finite[$i].wall_seconds -le $Start) {$left=$i}
        if($right -lt 0 -and $finite[$i].wall_seconds -ge $End) {$right=$i}
    }
    # Nearest bracketing samples, not unrelated transitions before/after them.
    if($left -lt 0 -or $right -le $left -or $Start-$finite[$left].wall_seconds -gt 1.5 -or $finite[$right].wall_seconds-$End -gt 1.5) {return $false}
    $window=@($finite[$left..$right])
    if($window.Count -lt 3) {return $false}
    $previous=[double]$window[0].wall_seconds
    $run=$window[0].runs
    foreach ($row in $window) {
        if ((Get-SoakFrameKey $row) -cne $Key -or $row.runs -ne $run -or $row.wall_seconds -lt $previous -or $row.wall_seconds-$previous -gt 1.6) { return $false }
        $previous=[double]$row.wall_seconds
    }
    return $true
}
function Test-SoakFrameReady([array]$Rows,[string]$Key) {
    if($Rows.Count -lt 2 -or !$Key) {return $false}
    $previous=$Rows[-2];$latest=$Rows[-1]
    $gap=[double]$latest.wall_seconds-[double]$previous.wall_seconds
    return (Get-SoakFrameKey $previous) -ceq $Key -and (Get-SoakFrameKey $latest) -ceq $Key -and
        $previous.runs -eq $latest.runs -and $gap -ge 0.5 -and $gap -le 1.6
}
function Get-SoakFrameSeconds([string]$Key) {
    if($Key.EndsWith('/overdrive')) {return 1}
    return 2
}
function Get-SoakCaptureBounds([double]$SampleWall,[DateTime]$PreviousRead,[DateTime]$Read,[DateTime]$CaptureStart,[DateTime]$CaptureEnd) {
    $pollGap=($Read-$PreviousRead).TotalSeconds
    if($pollGap -le 0 -or $pollGap -gt 1.6 -or $CaptureStart -lt $Read -or $CaptureEnd -le $CaptureStart -or
        ![double]::IsFinite($SampleWall) -or $SampleWall -lt 0) {return $null}
    # A new complete row appeared between reads. Preserve that uncertainty,
    # plus 100 ms for sampling/flush; never treat a stale row as capture start.
    return @{start=[Math]::Max(0.0,$SampleWall+($CaptureStart-$Read).TotalSeconds-.1);
        end=$SampleWall+($CaptureEnd-$PreviousRead).TotalSeconds+.1}
}
