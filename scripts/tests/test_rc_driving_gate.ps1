#requires -Version 7.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'rc_driving_gate.ps1')
$root = Join-Path (Join-Path $PSScriptRoot '../../tmp') ('driving-gate-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $root)
$trace = Join-Path $root 'synthetic.jsonl'
$start = @{event='capture_started';schema=1;pid=1234;session='1234-test';debug_build=$false;elapsed_usec=0}
# Main emits phase=running with screen=race; screen is a visible UI, not a phase name.
$sample = @{event='sample';schema=1;pid=1234;session='1234-test';phase='running';screen='race';focused=$true;speed=280.0;run_number=1;window_width=1920;window_height=1080;elapsed_usec=9000000}
$count = 0
function Check-Gate($row, [bool]$expected, [string]$label, [double]$age=10) {
    @($start, $row) | ForEach-Object { ConvertTo-Json $_ -Compress } | Set-Content -LiteralPath $trace -Encoding utf8
    $result = Get-RcDrivingGate -TracePath $trace -GamePid 1234 -GameUptimeSeconds $age
    if ($result.ready -ne $expected) { throw "$label expected $expected, got $($result.ready): $($result.reason)" }
    $script:count++
    Write-Output "PASS $label"
}
Check-Gate $sample $true 'fresh focused 1080p driving'
foreach ($phase in @('title','countdown','paused','game_over','run_clear')) {
    $row=$sample.Clone(); $row.phase=$phase; $row.screen=$phase
    Check-Gate $row $false "reject $phase"
}
foreach ($change in @(
    @{focused=$false}, @{focused='true'}, @{speed=0}, @{speed=-1},
    @{speed='NaN'}, @{run_number=0}, @{window_width=1280}, @{window_height=1440},
    @{pid=999}, @{session='1234-old'}, @{schema=2}, @{screen='settings'}, @{screen='running'},
    @{elapsed_usec=-1}, @{event='capture_closed'}
)) {
    $row=$sample.Clone();foreach($key in $change.Keys){$row[$key]=$change[$key]}
    Check-Gate $row $false ('reject '+($change|ConvertTo-Json -Compress))
}
Check-Gate $sample $false 'reject stale sample' 30
Check-Gate $sample $false 'reject future sample' 8
Check-Gate $sample $true 'accept zero age boundary' 9
Check-Gate $sample $true 'accept five second boundary' 14
Check-Gate $sample $false 'reject outside freshness boundary' 14.001
$start.debug_build=$true; Check-Gate $sample $false 'reject debug entry'; $start.debug_build=$false
$start.pid=999; Check-Gate $sample $false 'reject other trace header'; $start.pid=1234
$row=$sample.Clone();$row.Remove('speed');Check-Gate $row $false 'reject missing speed'
# A torn latest row must not fall back to an earlier valid running sample.
@($start,$sample)|ForEach-Object{ConvertTo-Json $_ -Compress}|Set-Content $trace -Encoding utf8
Add-Content $trace '{"event":"sample",' -Encoding utf8
if((Get-RcDrivingGate $trace 1234 10).ready){throw 'Torn latest row accepted'}; $count++
if((Get-RcDrivingGate (Join-Path $root 'absent.jsonl') 1234 10).ready){throw 'Missing trace accepted'}; $count++
$last=$sample.Clone();$last.phase='title';$last.screen='title'
@($start,$sample,$last)|ForEach-Object{ConvertTo-Json $_ -Compress}|Set-Content $trace -Encoding utf8
if((Get-RcDrivingGate $trace 1234 10).ready){throw 'Historical driving accepted after returning to title'}; $count++
# Exercise the same shared file mode used by the actual running game writer.
@($start,$sample)|ForEach-Object{ConvertTo-Json $_ -Compress}|Set-Content $trace -Encoding utf8
$writer=[IO.FileStream]::new($trace,[IO.FileMode]::Open,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite)
try {if(-not (Get-RcDrivingGate $trace 1234 10).ready){throw 'Shared live trace unreadable'}}finally{$writer.Dispose()}; $count++
if(-not (Get-RcDrivingGate -TracePath $trace -GamePid 1234 -GameUptimeSeconds 30 -CaptureStartUptimeSeconds 20).ready){throw 'Slow engine initialization incorrectly treated as stale driving'}; $count++
Write-Output "TEST_COMPLETE test_rc_driving_gate.ps1 cases=$count fixtures=$root"
