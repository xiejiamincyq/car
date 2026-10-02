param(
    [string]$GodotExecutable = "",
    [string]$TestFilter = "test_*.gd",
    [ValidateRange(1, 600)]
    [int]$TestTimeoutSeconds = 120
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
# These stateful/async completion gates carry explicit terminal evidence in
# addition to a normal process exit. Other legacy tests still exit themselves.
$completionRequired = @(
    "test_playtest_isolation.gd", "test_playtest_recorder.gd", "test_playtest_recording_flow.gd",
    "test_save_store.gd", "test_persistence_integration.gd", "test_audio_settings_ui.gd",
    "test_audio_teardown.gd", "test_dynamic_pickup_smoke.gd", "test_rating_ui.gd",
    "test_persistence_restart.gd", "test_forward_overdrive_input.gd",
    "test_save_recovery.gd", "test_save_feedback.gd", "test_tail_transform.gd",
    "test_main_persistence_mode.gd", "test_product_copy.gd"
)
$tests = @(Get-ChildItem (Join-Path $projectRoot "tests") -File -Filter $TestFilter | Sort-Object Name)
if ($tests.Count -eq 0) {
    throw "No tests matched '$TestFilter'."
}

foreach ($test in $tests) {
    Write-Host "RUN $($test.Name)"
    $logToken = [Guid]::NewGuid().ToString("N")
    $stdoutPath = Join-Path ([IO.Path]::GetTempPath()) "neon-coast-$logToken.stdout.log"
    $stderrPath = Join-Path ([IO.Path]::GetTempPath()) "neon-coast-$logToken.stderr.log"
    $process = Start-Process -FilePath $GodotExecutable `
        -ArgumentList @("--headless", "--path", "`"$projectRoot`"", "--script", "res://tests/$($test.Name)") `
        -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    # --quit-after counts engine frames and may exit 0 before an async test's
    # assertions execute. Only the test may signal success; the wall-clock
    # watchdog terminates our own child process and records timeout as failure.
    $deadline = [DateTime]::UtcNow.AddSeconds($TestTimeoutSeconds)
    $timedOut = $false
    while (-not $process.WaitForExit(250)) {
        if ([DateTime]::UtcNow -ge $deadline) {
            $timedOut = $true
            $process.Kill()
            $process.WaitForExit()
            break
        }
    }
    $process.Refresh()
    $standardOutput = Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue
    $standardError = Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    $combinedOutput = "$standardOutput`n$standardError"
    if (-not [string]::IsNullOrWhiteSpace($combinedOutput)) {
        Write-Host $combinedOutput.Trim()
    }

    $hasScriptFailure = $combinedOutput -match "SCRIPT ERROR:|Assertion failed:|Parse Error:|Failed to load script|ERROR: Node not found"
    $missingCompletion = $completionRequired -contains $test.Name -and
        $combinedOutput -notmatch ("(?m)^TEST_COMPLETE " + [regex]::Escape($test.Name) + "\s*$")
    if ($timedOut) {
        Write-Host "TIMEOUT $($test.Name) after $TestTimeoutSeconds seconds (failed, not passed)"
    }
    if ($missingCompletion) {
        Write-Host "INCOMPLETE $($test.Name): expected terminal marker was not reached"
    }
    if ($timedOut -or $process.ExitCode -ne 0 -or $hasScriptFailure -or $missingCompletion) {
        $failed += $test.Name
    }
}

if ($failed.Count -gt 0) {
    throw "Failed tests: $($failed -join ', ')"
}

Write-Host "ALL $($tests.Count) TESTS PASSED"
