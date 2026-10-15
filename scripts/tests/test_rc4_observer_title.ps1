#requires -Version 7.0
# One real title-only negative control for the new observer, not a performance test.
$ErrorActionPreference='Stop'
if(Get-Process -Name NeonCoastRush -ErrorAction SilentlyContinue){throw 'Refusing duplicate game'}
$build=(Resolve-Path (Join-Path $PSScriptRoot '../../exports/0.4.0-rc.4/ec39af0-17541495')).Path
$package=Join-Path $build 'package';$exe=Join-Path $package 'NeonCoastRush.exe'
$exeHash=(Get-FileHash -LiteralPath $exe).Hash;$packHash=(Get-FileHash -LiteralPath (Join-Path $package 'NeonCoastRush.pck')).Hash
if($exeHash -ne '053DCE777559CF604E88D80C2D3FED8747819B710D8526E3D3F6B76354F1188E' -or $packHash -ne 'AC6CAE8ABB38FB52BE7BBF192130B6BD106B8F08AD476FF6700E4C9A885D9875'){throw 'Immutable package mismatch'}
$root=Join-Path $build ('observer-title-test-'+[guid]::NewGuid().ToString('N'))
$appdata=Join-Path $root 'appdata';[void](New-Item -ItemType Directory -Path $appdata)
$gameInfo=[Diagnostics.ProcessStartInfo]::new()
$gameInfo.FileName=$exe;$gameInfo.WorkingDirectory=$package;$gameInfo.UseShellExecute=$false;$gameInfo.CreateNoWindow=$true
$gameInfo.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
$gameInfo.Environment['APPDATA']=$appdata;$gameInfo.Environment['NEON_COAST_PERF_CAPTURE']='1'
foreach($argument in @('--log-file',(Join-Path $root 'game.log'),'--windowed','--resolution','1920x1080','--max-fps','240','--quit-after','1440')){[void]$gameInfo.ArgumentList.Add($argument)}
$game=[Diagnostics.Process]::new();$game.StartInfo=$gameInfo
if(-not $game.Start()){throw 'Owned diagnostic game did not start'}
@{pid=$game.Id;executable=$exe;exe_sha256=$exeHash;pack_sha256=$packHash;appdata=$appdata;capture_enabled=$true;started_utc=$game.StartTime.ToUniversalTime().ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'handoff.json') -Encoding utf8
[void]$game.WaitForExit(1000)
$info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=(Get-Command pwsh).Source
$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
foreach($argument in @('-NoProfile','-File',(Join-Path $PSScriptRoot 'observe_rc4_driving.ps1'),'-HandoffDirectory',$root,'-WaitSeconds','1')){[void]$info.ArgumentList.Add($argument)}
$observer=[Diagnostics.Process]::new();$observer.StartInfo=$info
try {
    if(-not $observer.Start()){throw 'Observer did not start'}
    $stdout=$observer.StandardOutput.ReadToEndAsync();$stderr=$observer.StandardError.ReadToEndAsync()
    if(-not $observer.WaitForExit(10000)){$observer.Kill();throw 'Only owned observer stopped after timeout; game left to auto-exit'}
    $observerExit=$observer.ExitCode
    $stdout.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $root 'observer-stdout.log') -Encoding utf8
    $stderr.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $root 'observer-stderr.log') -Encoding utf8
    $directories=@(Get-ChildItem -LiteralPath $root -Directory -Filter 'observation-*')
    if($directories.Count -ne 1){throw 'Observer did not reach valid live handoff wait'}
    $record=Get-Content -LiteralPath (Join-Path $directories[0].FullName 'observation-terminal.json') -Raw | ConvertFrom-Json
    if($observerExit -ne 2 -or $record.gate.ready -or $record.collector_started -or $record.gate.reason -ne 'not_focused_1080p_running'){throw 'Title did not refuse capture as expected'}
    if(Test-Path -LiteralPath (Join-Path $directories[0].FullName 'graphics.etl')){throw 'Title-only test unexpectedly started ETW capture'}
    if(-not $game.WaitForExit(20000)){throw 'Auto-exit game still alive; do not force-close or count as terminated'}
    if($game.ExitCode -ne 0){throw 'Diagnostic game exited abnormally'}
    $trace=Get-Content -LiteralPath $record.trace | ConvertFrom-Json
    $samples=@($trace | Where-Object {$_.event -eq 'sample'})
    if($samples.Count -lt 1 -or @($samples|Where-Object {$_.phase -ne 'title' -or $_.run_number -ne 0}).Count -ne 0){throw 'Expected only normal title samples'}
    @{passed=$true;game_exit=$game.ExitCode;observer_exit=$observerExit;title_samples=$samples.Count;collector_started=$false;
        scope='Valid immutable live handoff reaches observer wait, but title never starts ETW. FPS capped only to bound this negative control; no driving/performance/human credit.'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'probe-terminal.json') -Encoding utf8
    Write-Output ('RC4_OBSERVER_TITLE_NEGATIVE_PASS '+$root)
} finally {$observer.Dispose();$game.Dispose()}
