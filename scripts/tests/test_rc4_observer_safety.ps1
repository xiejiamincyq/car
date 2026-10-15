#requires -Version 7.0
$ErrorActionPreference='Stop'
$candidateRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../exports/0.4.0-rc.4/ec39af0-17541495')).Path
$root=Join-Path $candidateRoot ('observer-safety-'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path (Join-Path $root 'appdata'))
$handoff=Get-Content (Join-Path $candidateRoot 'manual-9b568789/handoff.json') -Raw | ConvertFrom-Json -AsHashtable
# The only live process referenced by synthetic cases is this test's own pwsh, never a game.
$handoff.pid=$PID;$handoff.started_utc=[Diagnostics.Process]::GetCurrentProcess().StartTime.ToUniversalTime().ToString('o')
$handoff.appdata=Join-Path $root 'appdata'
$count=0
function Check-Refusal([hashtable]$inputHandoff,[string]$directory,[string]$expected,[string]$label){
    if($directory -eq $root){$inputHandoff | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $root 'handoff.json') -Encoding utf8}
    $info=[Diagnostics.ProcessStartInfo]::new()
    $info.FileName=(Get-Command pwsh).Source;$info.UseShellExecute=$false;$info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    foreach($argument in @('-NoProfile','-File',(Join-Path $PSScriptRoot 'observe_rc4_driving.ps1'),'-HandoffDirectory',$directory,'-WaitSeconds','1','-WaitOnly')){[void]$info.ArgumentList.Add($argument)}
    $process=[Diagnostics.Process]::new();$process.StartInfo=$info
    if(-not $process.Start()){throw 'Test subprocess failed to start'}
    $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
    if(-not $process.WaitForExit(10000)){$process.Kill();throw 'Refusal test hung; only owned test process stopped'}
    $exitCode=$process.ExitCode;$output=$stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult();$process.Dispose()
    if($exitCode -ne 2 -or $output -notmatch [regex]::Escape($expected)){throw "${label}: expected refusal 2/$expected, got $exitCode/$output"}
    if(Get-ChildItem -LiteralPath $root -Directory -Filter 'observation-*'){throw 'Refused handoff created observation output'}
    $script:count++;Write-Output "PASS $label"
}
Check-Refusal $handoff $root 'live_process_identity' 'reject live non-game process even with immutable handoff hashes'
$row=$handoff.Clone();$row.pid=0
Check-Refusal $row $root 'handoff_pid' 'reject zero PID'
$row=$handoff.Clone();$row.pid=1.5
Check-Refusal $row $root 'handoff_pid' 'reject fractional PID'
$row=$handoff.Clone();$row.capture_enabled='true'
Check-Refusal $row $root 'handoff_isolation' 'reject string capture flag'
$row=$handoff.Clone();$row.appdata=Join-Path $candidateRoot 'manual-9b568789/appdata'
Check-Refusal $row $root 'handoff_isolation' 'reject other handoff userdata'
$row=$handoff.Clone();$row.exe_sha256='wrong'
Check-Refusal $row $root 'immutable_identity' 'reject wrong EXE digest'
$row=$handoff.Clone();$row.pack_sha256='wrong'
Check-Refusal $row $root 'immutable_identity' 'reject wrong PCK digest'
$row=$handoff.Clone();$row.started_utc='not-a-date'
Check-Refusal $row $root 'handoff_timestamp' 'reject invalid start time'
Check-Refusal $handoff (Join-Path $candidateRoot 'package') 'handoff_scope' 'reject package as output root'
Check-Refusal $handoff (Resolve-Path (Join-Path $PSScriptRoot '../../tmp')).Path 'handoff_scope' 'reject outside candidate evidence'
Write-Output "RC4_OBSERVER_SAFETY_TESTS_COMPLETE $count"
