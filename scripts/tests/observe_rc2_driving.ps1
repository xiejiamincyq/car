#requires -Version 7.0
param(
    [ValidateRange(1, 2400)][int]$Seconds = 1800,
    [Parameter(Mandatory=$true)][string]$HandoffDirectory,
    [ValidateRange(1, 3600)][int]$WaitSeconds = 1800,
    [switch]$WaitOnly
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'rc_driving_gate.ps1')
$candidateRoot = (Resolve-Path 'C:/Users/21604/Documents/car/exports/0.4.0-rc.2/2a4d839-5c48bdf4').Path
$handoffDir = (Resolve-Path -LiteralPath (Join-Path $candidateRoot $HandoffDirectory)).Path
if (-not $handoffDir.StartsWith(($candidateRoot+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase) -or $handoffDir.StartsWith((Join-Path $candidateRoot 'package'),[StringComparison]::OrdinalIgnoreCase)) { throw 'Handoff must stay within owned build evidence, outside package' }
$handoff = Get-Content -LiteralPath (Join-Path $handoffDir 'handoff.json') -Raw | ConvertFrom-Json
$expectedExe = Join-Path $candidateRoot 'package/NeonCoastRush.exe'
$expectedPack = Join-Path $candidateRoot 'package/NeonCoastRush.pck'
$toolPath = (Resolve-Path 'C:/Users/21604/Documents/car/tmp/presentmon-2.6.0/PresentMon-2.6.0-x64.exe').Path
$exeHash=(Get-FileHash -LiteralPath $expectedExe).Hash
$packHash=(Get-FileHash -LiteralPath $expectedPack).Hash
if ($handoff.executable -ne $expectedExe -or $exeHash -ne '2DAAA00880E8A9123B966B45BEE6DD9B6D7F288E7485C3DB1FB28867768B9811' -or $packHash -ne 'EDEA4A1CA684809FF055D79683C41AE7FCA65448894623C497601F8AACA39C17' -or $handoff.exe_sha256 -ne $exeHash -or $handoff.pack_sha256 -ne $packHash) { throw 'Immutable RC identity mismatch' }
if ((Get-FileHash -LiteralPath $toolPath).Hash -ne 'B2A706BC6AD475749E3B7E3409263AA1E6906D45BDCF993F6DBC0F660188F1AF' -or (Get-AuthenticodeSignature -LiteralPath $toolPath).Status -ne 'Valid') { throw 'Portable capture tool verification failed' }
$gameProcess = [Diagnostics.Process]::GetProcessById([int]$handoff.pid)
$gameHandle = $gameProcess.Handle
$processInfo = Get-CimInstance Win32_Process -Filter ('ProcessId=' + $handoff.pid)
# ConvertFrom-Json may already return a UTC DateTime. Parsing its string cast loses the timezone.
$handoffStart = if ($handoff.started_utc) { $handoff.started_utc } else { $handoff.created_utc }
$recordedStart = if ($handoffStart -is [DateTime]) { $handoffStart.ToUniversalTime() } else { [DateTimeOffset]::Parse([string]$handoffStart, [Globalization.CultureInfo]::InvariantCulture).UtcDateTime }
if ($gameProcess.HasExited -or $processInfo.ExecutablePath -ne $expectedExe -or [Math]::Abs(($gameProcess.StartTime.ToUniversalTime() - $recordedStart).TotalSeconds) -gt 2) { throw 'Original manual game is absent or PID was reused' }
$userdata = (Resolve-Path -LiteralPath $handoff.appdata).Path
if (-not $userdata.StartsWith(($handoffDir+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase) -or
    $handoff.capture_enabled -isnot [bool] -or -not $handoff.capture_enabled) { throw 'Expected explicitly isolated, capture-enabled handoff' }
$traceDirectory = Join-Path $userdata 'Godot/app_userdata/Neon Coast Rush/performance'
$observationDir = Join-Path $handoffDir ('observation-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $observationDir | Out-Null
$waitStarted = [DateTime]::UtcNow
$gate = @{ready=$false;reason='trace_unavailable';sample=$null}
$tracePath = $null
Write-Output ('RC_DRIVING_WAIT_STARTED ' + $observationDir)
while (-not $gameProcess.HasExited -and [DateTime]::UtcNow -lt $waitStarted.AddSeconds($WaitSeconds)) {
    $traces = @(Get-ChildItem -LiteralPath $traceDirectory -Filter ('capture-'+$gameProcess.Id+'-*.jsonl') -File -ErrorAction SilentlyContinue)
    if ($traces.Count -gt 1) { throw 'Ambiguous trace for live process; refusing to select an old session' }
    if ($traces.Count -eq 1) {
        $tracePath=$traces[0].FullName
        $captureOffset=($traces[0].CreationTimeUtc-$gameProcess.StartTime.ToUniversalTime()).TotalSeconds
        $gate=Get-RcDrivingGate -TracePath $tracePath -GamePid $gameProcess.Id -GameUptimeSeconds ([DateTime]::UtcNow-$gameProcess.StartTime.ToUniversalTime()).TotalSeconds -CaptureStartUptimeSeconds $captureOffset
        if ($gate.ready) { break }
    }
    [void]$gameProcess.WaitForExit(500)
}
$waitRecord = @{ready=$gate.ready;reason=$gate.reason;wait_seconds=([DateTime]::UtcNow-$waitStarted).TotalSeconds;game_pid=$gameProcess.Id;game_still_running=(-not $gameProcess.HasExited);trace=$tracePath;trigger_sample=$gate.sample;wait_only=[bool]$WaitOnly;collector_started=$false;scope='External gate only: fresh focused 1080p nonzero-speed running sample. Not proof of a human run, 30 minutes, frame performance or complete driving coverage.'}
$waitRecord | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $observationDir 'driving-gate.json') -Encoding utf8
if (-not $gate.ready -or $gameProcess.HasExited) {
    $waitRecord | ConvertTo-Json -Depth 6
    $gameProcess.Dispose()
    exit 2
}
if ($WaitOnly) {
    $waitRecord | ConvertTo-Json -Depth 6
    $gameProcess.Dispose()
    exit 0
}
$csvPath = Join-Path $observationDir 'frames.csv'
$memoryPath = Join-Path $observationDir 'memory.csv'
$sessionName = 'CarRC2Manual-' + [Guid]::NewGuid().ToString('N')
$captureInfo = [Diagnostics.ProcessStartInfo]::new()
$captureInfo.FileName = $toolPath
$captureInfo.Arguments = '--process_id ' + $handoff.pid + ' --output_file "' + $csvPath + '" --session_name ' + $sessionName + ' --timed ' + $Seconds + ' --terminate_after_timed --terminate_on_proc_exit --no_console_stats --no_track_input --v1_metrics'
$captureInfo.UseShellExecute = $false
$captureInfo.RedirectStandardOutput = $true
$captureInfo.RedirectStandardError = $true
$captureInfo.CreateNoWindow = $true
$captureInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
$captureProcess = [Diagnostics.Process]::new()
$captureProcess.StartInfo = $captureInfo
$started = [DateTime]::UtcNow
if (-not $captureProcess.Start()) { throw 'PresentMon did not start' }
$waitRecord.collector_started=$true
$waitRecord | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $observationDir 'driving-gate.json') -Encoding utf8
$captureOut = $captureProcess.StandardOutput.ReadToEndAsync()
$captureErr = $captureProcess.StandardError.ReadToEndAsync()
@{game_pid=$gameProcess.Id;game_started_utc=$gameProcess.StartTime.ToUniversalTime().ToString('o');capture_pid=$captureProcess.Id;started_utc=$started.ToString('o');seconds=$Seconds;arguments=$captureInfo.Arguments;exe_sha256=$handoff.exe_sha256;pack_sha256=$handoff.pack_sha256;trigger_sample=$gate.sample;trace=$tracePath;scope='Read-only observation started after a live driving gate. No input injection, window activation, game shutdown, elevation, input tracking or gate waiver. Later title/pause/stationary samples remain in raw output; independent coverage analysis is required.'} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $observationDir 'start.json') -Encoding utf8
Write-Output ('RC_MANUAL_OBSERVATION_STARTED ' + $observationDir)
$memoryWriter = [IO.StreamWriter]::new($memoryPath, $false, [Text.UTF8Encoding]::new($false))
$memoryWriter.AutoFlush = $true
$memoryWriter.WriteLine('utc,elapsed_seconds,working_set_bytes,private_memory_bytes,cpu_seconds')
$watchdogTimeout = $false
$sampleCount = 0
try {
    while (-not $captureProcess.HasExited) {
        if (-not $gameProcess.HasExited) {
            try {
                $gameProcess.Refresh()
                $memoryWriter.WriteLine(('{0},{1},{2},{3},{4}' -f [DateTime]::UtcNow.ToString('o'), ([DateTime]::UtcNow-$started).TotalSeconds.ToString('F6', [Globalization.CultureInfo]::InvariantCulture), $gameProcess.WorkingSet64, $gameProcess.PrivateMemorySize64, $gameProcess.TotalProcessorTime.TotalSeconds.ToString('F6', [Globalization.CultureInfo]::InvariantCulture)))
                $sampleCount += 1
            } catch { if (-not $gameProcess.HasExited) { throw } }
        }
        if ([DateTime]::UtcNow -gt $started.AddSeconds($Seconds + 30)) {
            $watchdogTimeout = $true
            # Only the observer-owned capture tool may be terminated. Never kill the manual game.
            $captureProcess.Kill()
            $captureProcess.WaitForExit()
            break
        }
        [void]$captureProcess.WaitForExit(1000)
    }
} finally { $memoryWriter.Dispose() }
$captureProcess.WaitForExit()
$captureExit = $captureProcess.ExitCode
$captureOut.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $observationDir 'stdout.log') -Encoding utf8
$captureErr.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $observationDir 'stderr.log') -Encoding utf8
$gameHasExited = $gameProcess.HasExited
@{capture_native_exit=$captureExit;watchdog_timeout=$watchdogTimeout;elapsed_seconds=([DateTime]::UtcNow-$started).TotalSeconds;memory_samples=$sampleCount;game_still_running=(-not $gameHasExited);game_native_exit=$(if ($gameHasExited) {$gameProcess.ExitCode} else {$null});csv_exists=(Test-Path -LiteralPath $csvPath);scope='Raw capture termination only, not a claim of 30-minute complex driving, full flow, no leak, 20 restart coverage or human acceptance.'} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $observationDir 'terminal.json') -Encoding utf8
$captureProcess.Dispose()
$gameProcess.Dispose()
Get-Content -LiteralPath (Join-Path $observationDir 'terminal.json')
if ($watchdogTimeout -or $captureExit -ne 0) { exit 1 }
exit 0
