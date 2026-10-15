#requires -Version 7.0
param([string]$ReplayDirectory='')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'rc_independent_capture.ps1')
$root = Join-Path (Join-Path $PSScriptRoot '../../tmp') ('independent-capture-test-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $root)
$csv = Join-Path $root 'synthetic.csv'
$stats = @{mode=0x08000001;events_lost=0;buffers_lost=0;stop_exit=0;file_limit_hit=$false}
$rows = @(
    @{ProcessID=1234;TimeInSeconds=0.1;msBetweenPresents=5;Dropped=0;Runtime='Other'},
    @{ProcessID=1234;TimeInSeconds=0.2;msBetweenPresents=25;Dropped=1;Runtime='Other'}
)
$count = 0
function Check-Capture($inputRows, $inputStats, [int]$parserExit, [bool]$expected, [string]$label) {
    $inputRows | Export-Csv -LiteralPath $csv -NoTypeInformation
    $health = Get-RcFrameCaptureHealth -CsvPath $csv -GamePid 1234 -Statistics $inputStats -ParserExit $parserExit
    if ($health.ready -ne $expected) { throw "$label expected $expected, got $($health.ready): $($health.reason)" }
    $script:count++
    Write-Host "PASS $label"
    return $health
}
$health = Check-Capture $rows $stats 0 $true 'valid independent target frames including dropped and slow frames'
if ($health.frames -ne 2 -or $health.dropped -ne 1 -or $health.over_20ms -ne 1) { throw 'Raw dropped/slow frame counts were hidden' }
foreach ($bad in @(
    @{mode=0x00400000}, @{events_lost=1}, @{buffers_lost=1}, @{stop_exit=5}, @{file_limit_hit=$true}
)) {
    $changed=$stats.Clone(); foreach($key in $bad.Keys){$changed[$key]=$bad[$key]}
    $null=Check-Capture $rows $changed 0 $false ('reject '+($bad|ConvertTo-Json -Compress))
}
$null=Check-Capture $rows $stats 1 $false 'reject native parser failure'
$null=Check-Capture @($rows[0]) $stats 0 $false 'reject one frame'
foreach ($bad in @(@{ProcessID=9999},@{TimeInSeconds='NaN'},@{msBetweenPresents=0},@{msBetweenPresents=-1},@{msBetweenPresents='Infinity'},@{Dropped=2},@{Runtime=''})) {
    $row=$rows[1].Clone();foreach($key in $bad.Keys){$row[$key]=$bad[$key]}
    $null=Check-Capture @($rows[0],$row) $stats 0 $false ('reject row '+($bad|ConvertTo-Json -Compress))
}
$row=$rows[1].Clone();$row.TimeInSeconds=0.05
$null=Check-Capture @($rows[0],$row) $stats 0 $false 'reject backwards frame clock'
$row=$rows[1].Clone();$row.Remove('msBetweenPresents')
$null=Check-Capture @($row,$row) $stats 0 $false 'reject missing frame interval header'
$health=Get-RcFrameCaptureHealth -CsvPath (Join-Path $root 'absent.csv') -GamePid 1234 -Statistics $stats -ParserExit 0
if($health.ready -or $health.reason -ne 'csv_missing'){throw 'Native zero without CSV must fail'}
$count++
Write-Output "RC_INDEPENDENT_CAPTURE_TESTS_COMPLETE $count"
if($ReplayDirectory){
    $positive=Get-RcFrameCaptureHealth -CsvPath (Join-Path $ReplayDirectory 'frames.csv') -GamePid 115656 -Statistics $stats -ParserExit 0
    if(-not $positive.ready -or $positive.frames -ne 1060){throw 'Original independently recorded target frame replay failed'}
    Write-Output 'RC_INDEPENDENT_CAPTURE_ORIGINAL_REPLAY_COMPLETE 1060'
}
