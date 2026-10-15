#requires -Version 7.0
# External-only tooling. A healthy frame channel is NOT a driving/performance pass.
function Get-RcFrameCaptureHealth {
    param([string]$CsvPath, [int]$GamePid, [hashtable]$Statistics, [int]$ParserExit)
    $health = @{ready=$false;reason='capture_invalid';frames=0;dropped=0;over_20ms=0}
    if ($ParserExit -ne 0) { $health.reason='parser_failed';return $health }
    if (($Statistics.mode -band 0x08000000) -eq 0 -or $null -eq $Statistics.mode) { $health.reason='not_independent';return $health }
    foreach($key in @('events_lost','buffers_lost','stop_exit')) {
        if ($null -eq $Statistics[$key] -or $Statistics[$key] -ne 0) { $health.reason=$key;return $health }
    }
    if ($Statistics.file_limit_hit -isnot [bool] -or $Statistics.file_limit_hit) { $health.reason='file_limit';return $health }
    if (-not (Test-Path -LiteralPath $CsvPath -PathType Leaf)) { $health.reason='csv_missing';return $health }
    if ((Get-Item -LiteralPath $CsvPath).Length -gt 32MB) { $health.reason='csv_oversize';return $health }
    try { $frames=@(Import-Csv -LiteralPath $CsvPath) } catch { $health.reason='csv_unreadable';return $health }
    $health.frames=$frames.Count
    if($frames.Count -lt 2){$health.reason='insufficient_frames';return $health}
    $previous=-1.0
    foreach($frame in $frames) {
        if ($frame.ProcessID -ne [string]$GamePid -or [string]::IsNullOrWhiteSpace($frame.Runtime) -or $frame.Dropped -notin @('0','1')) { $health.reason='row_identity_or_schema';return $health }
        $timestamp=0.0;$interval=0.0
        if (-not [double]::TryParse($frame.TimeInSeconds,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$timestamp) -or
            -not [double]::TryParse($frame.msBetweenPresents,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$interval) -or
            -not [double]::IsFinite($timestamp) -or -not [double]::IsFinite($interval) -or $timestamp -lt 0 -or $timestamp -lt $previous -or $interval -le 0) {
            $health.reason='invalid_frame_clock';return $health
        }
        $previous=$timestamp
        if($frame.Dropped -eq '1'){$health.dropped++}
        if($interval -gt 20){$health.over_20ms++}
    }
    $health.ready=$true;$health.reason='frame_channel_available'
    return $health
}

function Invoke-RcIndependentCapture {
    param(
        [Parameter(Mandatory)][Diagnostics.Process]$GameProcess,
        [Parameter(Mandatory)][string]$ToolPath,
        [Parameter(Mandatory)][string]$OutputDirectory,
        [ValidateRange(1,10)][int]$Seconds=5
    )
    if (-not $IsWindows -or [IntPtr]::Size -ne 8) { throw 'Windows x64 required' }
    if ((Get-FileHash -LiteralPath $ToolPath).Hash -ne 'B2A706BC6AD475749E3B7E3409263AA1E6906D45BDCF993F6DBC0F660188F1AF' -or
        (Get-AuthenticodeSignature -LiteralPath $ToolPath).Status -ne 'Valid') { throw 'PresentMon identity/signature mismatch' }
    $directory=(Resolve-Path -LiteralPath $OutputDirectory).Path
    $etl=Join-Path $directory 'graphics.etl';$csv=Join-Path $directory 'frames.csv'
    foreach($name in @('graphics.etl','frames.csv','frame-terminal.json','parser-stdout.log','parser-stderr.log')) {
        if(Test-Path -LiteralPath (Join-Path $directory $name)){throw 'Refusing to overwrite prior capture evidence'}
    }
    if (-not ('CarRcCapture.IndependentEtw' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'rc_independent_etw.cs') }
    $GameProcess.Refresh()
    if ($GameProcess.HasExited) { throw 'Target process already exited' }
    $targetHandle=$GameProcess.Handle # Retain the original process identity across possible PID reuse.
    $started=[DateTime]::UtcNow
    $native=[CarRcCapture.IndependentEtw]::Capture($etl,$Seconds)
    $captureEnded=[DateTime]::UtcNow
    $gameAliveAtCaptureEnd=-not $GameProcess.HasExited
    $stats=@{mode=$native.Mode;events_lost=$native.EventsLost;buffers_lost=$native.BuffersLost;stop_exit=$native.StopExit;file_limit_hit=$false}
    if(Test-Path -LiteralPath $etl){$stats.file_limit_hit=(Get-Item -LiteralPath $etl).Length -ge (128MB-64KB)}
    $parserExit=-1;$timeout=$false
    if (-not $native.Error -and $native.StopExit -eq 0) {
        $info=[Diagnostics.ProcessStartInfo]::new()
        $info.FileName=$ToolPath;$info.UseShellExecute=$false;$info.CreateNoWindow=$true
        $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
        foreach($argument in @('--etl_file',$etl,'--process_id',[string]$GameProcess.Id,'--output_file',$csv,'--no_console_stats','--no_track_input','--v1_metrics')) {[void]$info.ArgumentList.Add($argument)}
        $parser=[Diagnostics.Process]::new();$parser.StartInfo=$info
        try {
            if(-not $parser.Start()){throw 'Offline parser failed to start'}
            $stdout=$parser.StandardOutput.ReadToEndAsync();$stderr=$parser.StandardError.ReadToEndAsync()
            if(-not $parser.WaitForExit(30000)){$timeout=$true;$parser.Kill();$parser.WaitForExit()}
            $parserExit=$parser.ExitCode
            $stdout.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $directory 'parser-stdout.log') -Encoding utf8
            $stderr.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $directory 'parser-stderr.log') -Encoding utf8
        } finally { $parser.Dispose() }
    }
    $health=Get-RcFrameCaptureHealth -CsvPath $csv -GamePid $GameProcess.Id -Statistics $stats -ParserExit $parserExit
    if($timeout -or $native.Error){$health.ready=$false;$health.reason=if($timeout){'parser_timeout'}else{'native_capture_failed'}}
    $result=@{started_utc=$started.ToString('o');capture_ended_utc=$captureEnded.ToString('o');ended_utc=[DateTime]::UtcNow.ToString('o');seconds=$Seconds;game_pid=$GameProcess.Id;
        game_started_utc=$GameProcess.StartTime.ToUniversalTime().ToString('o');game_alive_at_capture_end=$gameAliveAtCaptureEnd;session=[CarRcCapture.IndependentEtw]::SessionName;native=$native;
        statistics=$stats;parser_exit=$parserExit;parser_timeout=$timeout;health=$health;
        scope='Bounded external graphics channel only. Raw dropped/slow frames retained. No input capture, game shutdown, driving coverage, human acceptance or performance-pass claim.'}
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $directory 'frame-terminal.json') -Encoding utf8
    return $result
}
