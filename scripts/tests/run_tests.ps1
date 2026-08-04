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
    $logToken = [Guid]::NewGuid().ToString("N")
    $stdoutPath = Join-Path ([IO.Path]::GetTempPath()) "neon-coast-$logToken.stdout.log"
    $stderrPath = Join-Path ([IO.Path]::GetTempPath()) "neon-coast-$logToken.stderr.log"
    $process = Start-Process -FilePath $GodotExecutable `
        -ArgumentList @("--headless", "--path", $projectRoot, "--quit-after", "60", "--script", "res://tests/$($test.Name)") `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $standardOutput = Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue
    $standardError = Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    $combinedOutput = "$standardOutput`n$standardError"
    if (-not [string]::IsNullOrWhiteSpace($combinedOutput)) {
        Write-Host $combinedOutput.Trim()
    }

    $hasScriptFailure = $combinedOutput -match "SCRIPT ERROR:|Assertion failed:|Parse Error:|Failed to load script|ERROR: Node not found"
    if ($process.ExitCode -ne 0 -or $hasScriptFailure) {
        $failed += $test.Name
    }
}

if ($failed.Count -gt 0) {
    throw "Failed tests: $($failed -join ', ')"
}

Write-Host "ALL $($tests.Count) TESTS PASSED"
