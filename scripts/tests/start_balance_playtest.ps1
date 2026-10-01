param(
    [ValidateRange(1, 10)][int]$Session = 1,
    [string]$GodotExecutable = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$sessions = @(
    @("neon_coast", "pulse_gt", "611"),
    @("freight_harbor", "driftwing", "2026"),
    @("storm_ridge", "flashpoint", "9001"),
    @("sunrise_express", "comet_rs", "611"),
    @("neon_coast", "tidebreaker", "2026"),
    @("freight_harbor", "aurora_x", "9001"),
    @("storm_ridge", "pulse_gt", "611"),
    @("sunrise_express", "driftwing", "2026"),
    @("storm_ridge", "comet_rs", "9001"),
    @("sunrise_express", "aurora_x", "611")
)
if ([string]::IsNullOrWhiteSpace($GodotExecutable)) {
    $GodotExecutable = Get-ChildItem "$env:LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot_*_win64.exe" |
        Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $GodotExecutable -or -not (Test-Path -LiteralPath $GodotExecutable)) {
    throw "Godot not found. Specify -GodotExecutable."
}
$selected = $sessions[$Session - 1]
$arguments = @("--path", ('"{0}"' -f $projectRoot), "--script", "res://tests/PlaytestLauncher.gd", "--", $selected[0], $selected[1], "standard", $selected[2])
$game = Start-Process -FilePath $GodotExecutable -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Normal -PassThru
Write-Output "Playtest $Session/10: $($selected -join ' / '), standard, PID=$($game.Id). Local recording enabled; career/settings saves disabled."
