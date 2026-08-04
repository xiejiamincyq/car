param(
    [string]$GodotExecutable = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

if ([string]::IsNullOrWhiteSpace($GodotExecutable)) {
    $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if ($null -ne $godotCommand) {
        $GodotExecutable = $godotCommand.Source
    } else {
        $packageRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*"
        $GodotExecutable = Get-ChildItem $packageRoot -Filter "Godot_*_console.exe" -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending |
            Select-Object -First 1 -ExpandProperty FullName
    }
}

if ([string]::IsNullOrWhiteSpace($GodotExecutable) -or -not (Test-Path -LiteralPath $GodotExecutable)) {
    throw "Godot console executable was not found. Pass -GodotExecutable explicitly."
}

$failed = @()
$tests = Get-ChildItem (Join-Path $projectRoot "tests") -Filter "test_*.gd" | Sort-Object Name

foreach ($test in $tests) {
    Write-Host "RUN $($test.Name)"
    $output = @(& $GodotExecutable --headless --path $projectRoot --quit-after 60 --script "res://tests/$($test.Name)" 2>&1)
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }

    $hasScriptFailure = $output -match "SCRIPT ERROR:|Assertion failed:|Parse Error:|Failed to load script"
    if ($exitCode -ne 0 -or $hasScriptFailure) {
        $failed += $test.Name
    }
}

if ($failed.Count -gt 0) {
    throw "Failed tests: $($failed -join ', ')"
}

Write-Host "ALL $($tests.Count) TESTS PASSED"
