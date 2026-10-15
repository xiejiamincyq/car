#requires -Version 7.0
param([Parameter(Mandatory)][string]$HandoffPath,[Parameter(Mandatory)][string]$ToolPath)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'soak_frame_contract.ps1')
. (Join-Path $PSScriptRoot 'rc_independent_capture.ps1')
$handoff=Get-Content -LiteralPath $HandoffPath -Raw | ConvertFrom-Json -AsHashtable
if ($handoff.pilot -isnot [bool] -or $handoff.pilot) { throw 'Full-run handoff required' }
$game=Get-Process -Id $handoff.pid
$identity=Get-CimInstance Win32_Process -Filter "ProcessId=$($game.Id)"
$handoffUtc=ConvertTo-SoakUtc $handoff.started_utc
if ($game.Path -cne $handoff.exe -or [Math]::Abs(($game.StartTime.ToUniversalTime()-$handoffUtc).TotalSeconds) -gt 2 -or
    $identity.CommandLine -notlike '*--script res://scripts/tests/RealtimeSoak.gd*' -or
    !$identity.CommandLine.Contains([string]$handoff.game_evidence)) { throw 'Live process identity mismatch' }
$retainedHandle=$game.Handle
$samplePath=Join-Path $handoff.game_evidence 'samples.jsonl'
$folder=Join-Path $handoff.evidence ('frames-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $folder | Out-Null
Write-Output "SOAK_FRAMES_STARTED $folder PID $($game.Id)"
$attempted=@{};$captures=[Collections.Generic.List[object]]::new()
$seenWall=$null;$lastReadUtc=$null
$toolSource=@{}
foreach($name in @('observe_soak_frames.ps1','soak_frame_contract.ps1','rc_independent_capture.ps1','rc_independent_etw.cs')) {
    $toolSource[$name]=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $name)).Hash
}
function Read-Context([int]$Tail=15) {
    $rows=[Collections.Generic.List[object]]::new()
    foreach ($line in Get-Content -LiteralPath $samplePath -Tail $Tail) {
        try { $row=ConvertFrom-Json -InputObject $line -AsHashtable -ErrorAction Stop; $rows.Add($row) } catch { }
    }
    return ,$rows.ToArray()
}
try {
    while (!$game.HasExited -and $attempted.Count -lt 12 -and [DateTime]::UtcNow -lt $handoffUtc.AddSeconds(2600)) {
        $rows=Read-Context
        if (!$rows.Count) { Start-Sleep -Milliseconds 500;continue }
        $before=$rows[-1];$readUtc=[DateTime]::UtcNow
        $previousReadUtc=$lastReadUtc;$lastReadUtc=$readUtc
        $fresh=$null -ne $seenWall -and $seenWall -ne $before.wall_seconds
        $seenWall=$before.wall_seconds
        $key=Get-SoakFrameKey $before
        # Wall time, not NTFS mtime: open append files can retain a cached creation mtime.
        $age=($readUtc-$handoffUtc).TotalSeconds-[double]$before.wall_seconds
        if (!$fresh -or $null -eq $previousReadUtc -or !$key -or $attempted.ContainsKey($key) -or $age -lt -2 -or $age -gt 3 -or
            !(Test-SoakFrameReady $rows $key) -or ($readUtc-$previousReadUtc).TotalSeconds -gt 1.6) { Start-Sleep -Milliseconds 500;continue }
        $attempted[$key]=$true
        $captureFolder=Join-Path $folder ($key.Replace('/','-'))
        New-Item -ItemType Directory -Path $captureFolder | Out-Null
        $seconds=Get-SoakFrameSeconds $key
        $channel=Invoke-RcIndependentCapture -GameProcess $game -ToolPath $ToolPath -OutputDirectory $captureFolder -Seconds $seconds
        $captureStart=ConvertTo-SoakUtc $channel.started_utc
        $captureEnd=ConvertTo-SoakUtc $channel.capture_ended_utc
        $bounds=Get-SoakCaptureBounds $before.wall_seconds $previousReadUtc $readUtc $captureStart $captureEnd
        if($null -eq $bounds) {throw 'Invalid fresh-sample capture clock bounds'}
        $startWall=$bounds.start;$endWall=$bounds.end
        Start-Sleep -Milliseconds 1200
        $context=Read-Context 45
        $consistent=Test-SoakFrameWindow $context $startWall $endWall $key
        $valid=$channel.health.ready -and $channel.game_alive_at_capture_end -and $consistent
        $metrics=$null
        if ($channel.health.ready) {
            $intervals=@(Import-Csv -LiteralPath (Join-Path $captureFolder 'frames.csv') | ForEach-Object { [double]::Parse($_.msBetweenPresents,[Globalization.CultureInfo]::InvariantCulture) } | Sort-Object)
            $metrics=@{raw_p95_ms=$intervals[[int][Math]::Ceiling($intervals.Count*.95)-1];raw_max_ms=$intervals[-1];frames=$channel.health.frames;dropped=$channel.health.dropped;over_20ms=$channel.health.over_20ms}
        }
        $record=@{key=$key;observed_context_consistent=$consistent;coverage_valid=[bool]$valid;before=$before;window_start=$startWall;window_end=$endWall;
            context=$context;metrics=$metrics;frame_terminal=(Join-Path $captureFolder 'frame-terminal.json')}
        $captures.Add($record)
        $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $captureFolder 'observed-context.json') -Encoding utf8
        Write-Output ('SOAK_FRAME_CAPTURE '+(@{key=$key;coverage_valid=[bool]$valid;metrics=$metrics} | ConvertTo-Json -Compress -Depth 5))
        $seenWall=$null;$lastReadUtc=$null
    }
} finally {
    $expected=@(foreach($track in @('neon_coast','freight_harbor','storm_ridge','sunrise_express')) { foreach($state in @('driving','construction','overdrive')) { "$track/$state" } })
    $covered=@($captures | Where-Object coverage_valid | ForEach-Object key)
    @{observer_version=2;tool_source_sha256=$toolSource;game_pid=$game.Id;game_started_utc=$game.StartTime.ToUniversalTime().ToString('o');attempted=@($attempted.Keys);covered=$covered;
        missing=@($expected | Where-Object {$_ -notin $covered});captures=$captures.ToArray();
        scope='Source-driver 1-second transient/2-second ordinary frames with bracketing 1 Hz observed context; not normal-entry release EXE, continuous focus or performance acceptance.'} |
        ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $folder 'coverage.json') -Encoding utf8
    Write-Output "SOAK_FRAMES_COMPLETE $folder"
    $game.Dispose()
}
