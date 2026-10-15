#requires -Version 7.0
# RC4 external observer: one bounded frame segment, never a whole acceptance verdict.
param(
    [Parameter(Mandatory)][string]$HandoffDirectory,
    [ValidateRange(1,3600)][int]$WaitSeconds=1200,
    [ValidateRange(1,10)][int]$FrameSeconds=5,
    [switch]$WaitOnly
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'rc_driving_gate.ps1')
. (Join-Path $PSScriptRoot 'rc_independent_capture.ps1')
$gameProcess=$null;$observationDir=$null;$reason='handoff_scope';$exitCode=2
try {
    $candidateRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../exports/0.4.0-rc.4/ec39af0-17541495')).Path
    $handoffPath=if([IO.Path]::IsPathRooted($HandoffDirectory)){$HandoffDirectory}else{Join-Path $candidateRoot $HandoffDirectory}
    $handoffDir=(Resolve-Path -LiteralPath $handoffPath).Path
    if(-not $handoffDir.StartsWith($candidateRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or
        $handoffDir.Replace('\','/') -match '/package(?:/|$)'){throw 'Handoff outside owned evidence or inside package'}
    $handoff=Get-Content -LiteralPath (Join-Path $handoffDir 'handoff.json') -Raw | ConvertFrom-Json
    $reason='handoff_pid'
    if(($handoff.pid -isnot [long] -and $handoff.pid -isnot [int]) -or $handoff.pid -le 0 -or $handoff.pid -gt [int]::MaxValue){throw 'Invalid PID'}
    $reason='handoff_isolation'
    $userdata=(Resolve-Path -LiteralPath $handoff.appdata).Path
    if(-not $userdata.StartsWith($handoffDir+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or
        $handoff.capture_enabled -isnot [bool] -or -not $handoff.capture_enabled){throw 'Expected isolated capture-enabled userdata'}
    $reason='immutable_identity'
    $expectedExe=(Resolve-Path -LiteralPath $handoff.executable).Path
    $expectedPack=Join-Path (Split-Path $expectedExe) 'NeonCoastRush.pck'
    if(-not $expectedExe.StartsWith($candidateRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($expectedExe) -ne 'NeonCoastRush.exe' -or
        $handoff.exe_sha256 -ne '053DCE777559CF604E88D80C2D3FED8747819B710D8526E3D3F6B76354F1188E' -or
        $handoff.pack_sha256 -ne 'AC6CAE8ABB38FB52BE7BBF192130B6BD106B8F08AD476FF6700E4C9A885D9875' -or
        (Get-FileHash -LiteralPath $expectedExe).Hash -ne $handoff.exe_sha256 -or
        (Get-FileHash -LiteralPath $expectedPack).Hash -ne $handoff.pack_sha256){throw 'Immutable RC4 identity mismatch'}
    $reason='handoff_timestamp'
    $recordedStart=if($handoff.started_utc -is [DateTime]){$handoff.started_utc.ToUniversalTime()}else{[DateTimeOffset]::Parse([string]$handoff.started_utc,[Globalization.CultureInfo]::InvariantCulture).UtcDateTime}
    $reason='live_process_identity'
    $gameProcess=[Diagnostics.Process]::GetProcessById([int]$handoff.pid)
    $gameHandle=$gameProcess.Handle
    $processInfo=Get-CimInstance Win32_Process -Filter ('ProcessId='+$handoff.pid)
    if($gameProcess.HasExited -or $processInfo.ExecutablePath -ne $expectedExe -or
        [Math]::Abs(($gameProcess.StartTime.ToUniversalTime()-$recordedStart).TotalSeconds) -gt 2){throw 'Original game absent or PID reused'}
    $reason='capture_tool_identity'
    $toolPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../tmp/presentmon-2.6.0/PresentMon-2.6.0-x64.exe')).Path
    if((Get-FileHash -LiteralPath $toolPath).Hash -ne 'B2A706BC6AD475749E3B7E3409263AA1E6906D45BDCF993F6DBC0F660188F1AF' -or
        (Get-AuthenticodeSignature -LiteralPath $toolPath).Status -ne 'Valid'){throw 'Capture tool hash/signature mismatch'}
    if(-not $WaitOnly){Add-Type -Path (Join-Path $PSScriptRoot 'rc_independent_etw.cs')}
    $traceDirectory=Join-Path $userdata 'Godot/app_userdata/Neon Coast Rush/performance'
    $observationDir=Join-Path $handoffDir ('observation-'+[guid]::NewGuid().ToString('N'))
    [void](New-Item -ItemType Directory -Path $observationDir)
    $waitStarted=[DateTime]::UtcNow;$tracePath=$null;$gate=@{ready=$false;reason='trace_unavailable';sample=$null}
    Write-Output ('RC4_DRIVING_WAIT_STARTED '+$observationDir)
    $reason='driving_wait'
    while(-not $gameProcess.HasExited -and [DateTime]::UtcNow -lt $waitStarted.AddSeconds($WaitSeconds)){
        $traces=@(Get-ChildItem -LiteralPath $traceDirectory -Filter ('capture-'+$gameProcess.Id+'-*.jsonl') -File -ErrorAction SilentlyContinue)
        if($traces.Count -gt 1){$reason='ambiguous_trace';throw 'Refusing multiple traces for the original process'}
        if($traces.Count -eq 1){
            $tracePath=$traces[0].FullName
            $captureOffset=($traces[0].CreationTimeUtc-$gameProcess.StartTime.ToUniversalTime()).TotalSeconds
            $gate=Get-RcDrivingGate -TracePath $tracePath -GamePid $gameProcess.Id -GameUptimeSeconds ([DateTime]::UtcNow-$gameProcess.StartTime.ToUniversalTime()).TotalSeconds -CaptureStartUptimeSeconds $captureOffset
            if($gate.ready){break}
        }
        [void]$gameProcess.WaitForExit(500)
    }
    $record=@{gate=$gate;trace=$tracePath;game_pid=$gameProcess.Id;wait_only=[bool]$WaitOnly;collector_requested=$false;collector_started=$false;
        scope='Fresh focused 1080p moving race trigger only; no human acceptance, full-span coverage or performance-pass claim.'}
    $record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $observationDir 'driving-gate.json') -Encoding utf8
    if($gate.ready -and -not $gameProcess.HasExited){
        if($WaitOnly){$exitCode=0}else{
            $reason='frame_capture';$record.collector_requested=$true
            $record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $observationDir 'driving-gate.json') -Encoding utf8
            $capture=Invoke-RcIndependentCapture -GameProcess $gameProcess -ToolPath $toolPath -OutputDirectory $observationDir -Seconds $FrameSeconds
            $record.collector_started=$capture.native.StartExit -eq 0
            $record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $observationDir 'driving-gate.json') -Encoding utf8
            $exitCode=if($capture.health.ready){0}else{1}
            $record.frame_health=$capture.health
        }
    }
    $record.exit_code=$exitCode;$record.game_still_running=-not $gameProcess.HasExited
    $record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $observationDir 'observation-terminal.json') -Encoding utf8
    Write-Output ('RC4_OBSERVATION_TERMINAL '+($record|ConvertTo-Json -Depth 6 -Compress))
} catch {
    Write-Output ('RC4_OBSERVATION_REFUSED '+$reason)
    if($observationDir){@{exit_code=1;reason=$reason;error=$_.Exception.Message} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $observationDir 'observation-terminal.json') -Encoding utf8;$exitCode=1}
} finally {if($gameProcess){$gameProcess.Dispose()}}
exit $exitCode
