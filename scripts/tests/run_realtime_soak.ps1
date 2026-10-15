param([string]$GodotExecutable = '', [switch]$Pilot)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
if (!$GodotExecutable) {
    $link = Get-Item (Get-Command godot -ErrorAction Stop).Source
    $target = if ($link.Target) { [string]$link.Target } else { $link.FullName }
    # The console launcher is a proxy process. Measure the actual GUI engine.
    $GodotExecutable = $target
}
$GodotExecutable = (Resolve-Path -LiteralPath $GodotExecutable).Path
$existing = @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*--script*RealtimeSoak.gd*' })
if ($existing.Count) { throw 'Existing soak driver found; inspect its live handle instead of starting another.' }
$evidence = Join-Path $projectRoot ('tmp/realtime-run-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $evidence 'appdata') | Out-Null
$gameEvidence = Join-Path $evidence 'game'
$formalFolder = Join-Path $env:APPDATA 'Godot/app_userdata/Neon Coast Rush'
function Get-FormalSnapshot {
    @('save.cfg','save.cfg.bak','save.cfg.tmp') | ForEach-Object {
        $path = Join-Path $formalFolder $_
        [pscustomobject]@{ name=$_; exists=(Test-Path -LiteralPath $path -PathType Leaf); sha256=$(if(Test-Path -LiteralPath $path -PathType Leaf){(Get-FileHash -LiteralPath $path).Hash}else{$null}) }
    }
}
$formalBefore = @(Get-FormalSnapshot)
$info = [Diagnostics.ProcessStartInfo]::new()
$info.FileName = $GodotExecutable
$info.WorkingDirectory = $projectRoot
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
$info.RedirectStandardOutput = $true
$info.RedirectStandardError = $true
$info.EnvironmentVariables['APPDATA'] = Join-Path $evidence 'appdata'
$info.Arguments = '--path "'+$projectRoot+'" --script res://scripts/tests/RealtimeSoak.gd --log-file "'+(Join-Path $evidence 'engine.log')+'" -- "'+$gameEvidence+'"'
if ($Pilot) { $info.Arguments += ' --pilot' }
$game = [Diagnostics.Process]::new()
$game.StartInfo = $info
if (!$game.Start()) { throw 'Driver launch failed' }
$stdout = $game.StandardOutput.ReadToEndAsync()
$stderr = $game.StandardError.ReadToEndAsync()
$started = [DateTime]::UtcNow
$handoff = @{pid=$game.Id;started_utc=$started.ToString('o');pilot=[bool]$Pilot;evidence=$evidence;game_evidence=$gameEvidence;exe=$GodotExecutable;formal_before=$formalBefore}
$handoff | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $evidence 'handoff.json')
Write-Output ('REALTIME_RUN '+$evidence+' PID '+$game.Id)
$memory = [Collections.Generic.List[object]]::new()
$memoryFile = [IO.StreamWriter]::new((Join-Path $evidence 'memory.jsonl'),$false)
$nextUpdate = $started
$timeout = $false
try {
    while (!$game.WaitForExit(1000)) {
        $game.Refresh()
        $row = @{utc=[DateTime]::UtcNow.ToString('o');private_bytes=$game.PrivateMemorySize64;working_set_bytes=$game.WorkingSet64;handles=$game.HandleCount}
        $samplePath = Join-Path $gameEvidence 'samples.jsonl'
        if (Test-Path -LiteralPath $samplePath) {
            try {
                $latest = Get-Content -LiteralPath $samplePath -Tail 1 | ConvertFrom-Json -ErrorAction Stop
                $row.phase=$latest.phase;$row.returns=$latest.returns;$row.track=$latest.track;$row.distance=$latest.distance;$row.driving_wall_seconds=$latest.driving_wall_seconds
            } catch {
                # A concurrent append can expose a partial last row. Keep the
                # process sample, retry next second; never restart the game.
                $row.sample_read_incomplete=$true
            }
        }
        $memory.Add([pscustomobject]$row)
        $memoryFile.WriteLine(($row | ConvertTo-Json -Compress))
        $memoryFile.Flush()
        if ([DateTime]::UtcNow -ge $nextUpdate) {
            Write-Output ('REALTIME_PROGRESS '+($row | ConvertTo-Json -Compress))
            $nextUpdate = [DateTime]::UtcNow.AddSeconds(30)
        }
        if (([DateTime]::UtcNow-$started).TotalSeconds -gt $(if($Pilot){180}else{2600})) {
            $timeout=$true
            $game.Kill() # This exact child only; never a user's unrelated game/editor.
            $game.WaitForExit()
            break
        }
    }
} finally { $memoryFile.Dispose() }
$game.WaitForExit()
$out = $stdout.GetAwaiter().GetResult()
$err = $stderr.GetAwaiter().GetResult()
[IO.File]::WriteAllText((Join-Path $evidence 'stdout.log'),$out)
[IO.File]::WriteAllText((Join-Path $evidence 'stderr.log'),$err)
$formalAfter = @(Get-FormalSnapshot)
$formalUnchanged = ($formalBefore | ConvertTo-Json -Compress) -ceq ($formalAfter | ConvertTo-Json -Compress)
$summaryPath = Join-Path $gameEvidence 'summary.json'
$summary = if (Test-Path -LiteralPath $summaryPath) { Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json } else { $null }
$runtimeErrors = ($out + $err) -match 'SCRIPT ERROR:|(?m)^ERROR:|Parse Error:'
$complete = $out -match '(?m)^REALTIME_SOAK_COMPLETE '
$valid = !$timeout -and $game.ExitCode -eq 0 -and !$runtimeErrors -and $complete -and $formalUnchanged -and $null -ne $summary -and $summary.source_stable
if (!$Pilot) { $valid = $valid -and $summary.full_pass }
$terminal = @{pid=$game.Id;exit_code=$game.ExitCode;timed_out=$timeout;complete_marker=$complete;runtime_errors=$runtimeErrors;formal_unchanged=$formalUnchanged;
    pilot=[bool]$Pilot;valid=[bool]$valid;wall_seconds=([DateTime]::UtcNow-$started).TotalSeconds;memory_samples=$memory.Count;
    private_first=$(if($memory.Count){$memory[0].private_bytes}else{$null});private_last=$(if($memory.Count){$memory[-1].private_bytes}else{$null});formal_after=$formalAfter}
$terminal | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $evidence 'terminal.json')
Write-Output ('REALTIME_TERMINAL '+($terminal | ConvertTo-Json -Depth 6 -Compress))
if (!$valid) { throw ('Realtime soak did not pass. Evidence retained: '+$evidence) }
