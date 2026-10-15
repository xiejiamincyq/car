#requires -Version 7.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'soak_frame_contract.ps1')
$checks = 0
function Assert-Equal($Actual, $Expected, [string]$Name) {
    if ($Actual -cne $Expected) { throw "$Name expected [$Expected], got [$Actual]" }
    $script:checks++
}
function Sample([double]$Time, [string]$Phase='RUNNING', [bool]$Construction=$false, [bool]$Overdrive=$false) {
    @{wall_seconds=$Time;runs=1;track='neon_coast';phase=$Phase;speed=300.0;construction=$Construction;overdrive=$Overdrive}
}
$jsonUtc=ConvertFrom-Json '{"utc":"2026-10-11T06:51:44.9268774Z"}'
Assert-Equal ((ConvertTo-SoakUtc $jsonUtc.utc).ToString('o')) '2026-10-11T06:51:44.9268774Z' 'JSON typed UTC preserved'
Assert-Equal ((ConvertTo-SoakUtc '2026-10-11T14:51:44.9268774+08:00').ToString('o')) '2026-10-11T06:51:44.9268774Z' 'explicit timezone string'
$rows = @(0..6 | ForEach-Object { Sample $_ })
Assert-Equal (Get-SoakFrameKey $rows[0]) 'neon_coast/driving' 'ordinary driving'
Assert-Equal (Get-SoakFrameKey (Sample 0 'PAUSED')) '' 'paused excluded'
$stopped=Sample 0;$stopped.speed=0
Assert-Equal (Get-SoakFrameKey $stopped) '' 'parked excluded'
Assert-Equal (Get-SoakFrameKey (Sample 0 'RUNNING' $true)) 'neon_coast/construction' 'construction'
Assert-Equal (Get-SoakFrameKey (Sample 0 'RUNNING' $true $true)) 'neon_coast/overdrive' 'overdrive precedence'
$unknown=Sample 0;$unknown.track='unknown'
Assert-Equal (Get-SoakFrameKey $unknown) '' 'unknown track'
$fourth=Sample 0;$fourth.track='sunrise_express'
Assert-Equal (Get-SoakFrameKey $fourth) 'sunrise_express/driving' 'actual fourth catalog track'
$missing=Sample 0;$missing.Remove('overdrive')
Assert-Equal (Get-SoakFrameKey $missing) '' 'missing state is not false'
$badType=Sample 0;$badType.construction='false'
Assert-Equal (Get-SoakFrameKey $badType) '' 'state type'
Assert-Equal (Test-SoakFrameWindow $rows 0.1 5.9 'neon_coast/driving') $true 'bounded consistent window'
Assert-Equal (Test-SoakFrameWindow @() 0 5 'neon_coast/driving') $false 'empty window'
Assert-Equal (Test-SoakFrameWindow $rows 10 15 'neon_coast/driving') $false 'stale window'
Assert-Equal (Test-SoakFrameWindow @($rows[0],$rows[6]) 0 6 'neon_coast/driving') $false 'missing internal samples'
Assert-Equal (Test-SoakFrameWindow $rows 6 0 'neon_coast/driving') $false 'reversed clock'
$mixed=@($rows | ForEach-Object { $_.Clone() });$mixed[3].construction=$true
Assert-Equal (Test-SoakFrameWindow $mixed 0.1 5.9 'neon_coast/driving') $false 'state transition'
$mixed=@($rows | ForEach-Object { $_.Clone() });$mixed[3].runs=2
Assert-Equal (Test-SoakFrameWindow $mixed 0.1 5.9 'neon_coast/driving') $false 'cross run'
$mixed=@($rows | ForEach-Object { $_.Clone() });$mixed[3].phase='PAUSED'
Assert-Equal (Test-SoakFrameWindow $mixed 0.1 5.9 'neon_coast/driving') $false 'pause within window'
$mixed=@($rows | ForEach-Object { $_.Clone() });$mixed[3].wall_seconds=[double]::NaN
Assert-Equal (Test-SoakFrameWindow $mixed 0.1 5.9 'neon_coast/driving') $false 'invalid clock'
$outside=@($rows | ForEach-Object {$_.Clone()});$outside[0].phase='PAUSED';$outside[5].phase='COUNTDOWN'
Assert-Equal (Test-SoakFrameWindow $outside 1.1 3.2 'neon_coast/driving') $true 'irrelevant transitions outside nearest bracketing samples'
Assert-Equal (Test-SoakFrameWindow @($rows[2],$rows[3],$rows[4]) 1.1 3.2 'neon_coast/driving') $false 'missing sample before capture'
Assert-Equal (Test-SoakFrameWindow @($rows[1],$rows[2],$rows[3]) 1.1 3.2 'neon_coast/driving') $false 'missing sample after capture'
Assert-Equal (Test-SoakFrameReady @($rows[1],$rows[2]) 'neon_coast/driving') $true 'stable sampled prefix'
Assert-Equal (Test-SoakFrameReady @((Sample 1 'PAUSED'),$rows[2]) 'neon_coast/driving') $false 'do not start on first resumed sample'
Assert-Equal (Test-SoakFrameReady @($rows[1],$rows[4]) 'neon_coast/driving') $false 'stale prefix'
$cross=$rows[2].Clone();$cross.runs=2
Assert-Equal (Test-SoakFrameReady @($rows[1],$cross) 'neon_coast/driving') $false 'cross-run prefix'
Assert-Equal (Get-SoakFrameSeconds 'neon_coast/overdrive') 1 'bounded transient capture'
Assert-Equal (Get-SoakFrameSeconds 'neon_coast/construction') 2 'bounded ordinary capture'
$utc=[DateTime]::Parse('2026-10-11T07:00:00Z').ToUniversalTime()
$bounds=Get-SoakCaptureBounds 100 $utc $utc.AddSeconds(.5) $utc.AddSeconds(.6) $utc.AddSeconds(1.6)
Assert-Equal ([Math]::Round($bounds.start,3)) 100.0 'lower clock bound retains fresh-sample read lag'
Assert-Equal ([Math]::Round($bounds.end,3)) 101.7 'upper clock bound uses native capture end'
$fractional=Get-SoakCaptureBounds 100.2 $utc $utc.AddSeconds(.5) $utc.AddSeconds(.6) $utc.AddSeconds(1.6)
Assert-Equal ([Math]::Round($fractional.start,3)) 100.2 'fractional lower bound is never rounded to integer seconds'
Assert-Equal (Get-SoakCaptureBounds 100 $utc $utc.AddSeconds(3) $utc.AddSeconds(3.1) $utc.AddSeconds(4.1)) $null 'reject slow polling interval'
Assert-Equal (Get-SoakCaptureBounds 100 $utc $utc.AddSeconds(.5) $utc.AddSeconds(.4) $utc.AddSeconds(1)) $null 'reject reversed observation clock'
Write-Output "SOAK_FRAME_CONTRACT_COMPLETE checks=$checks"
