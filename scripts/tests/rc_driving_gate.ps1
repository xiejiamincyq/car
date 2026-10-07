#requires -Version 7.0
# External observer gate; never loaded by the game or included in the player package.
function Get-RcDrivingGate {
    param([string]$TracePath, [int]$GamePid, [double]$GameUptimeSeconds, [double]$CaptureStartUptimeSeconds=0)
    $rejected = @{ready=$false;reason='trace_unavailable';sample=$null}
    if (-not (Test-Path -LiteralPath $TracePath -PathType Leaf)) { return $rejected }
    try {
        $stream = [IO.FileStream]::new($TracePath,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
        try {
            if ($stream.Length -gt 16MB) { $rejected.reason='trace_oversize'; return $rejected }
            $reader = [IO.StreamReader]::new($stream,[Text.Encoding]::UTF8,$true)
            try { $lines=$reader.ReadToEnd().TrimEnd("`r","`n") -split "`n" } finally { $reader.Dispose() }
        } finally { $stream.Dispose() }
        if ($lines.Count -lt 2) { $rejected.reason='trace_not_started'; return $rejected }
        $header=$lines[0] | ConvertFrom-Json -AsHashtable
        $row=$lines[-1] | ConvertFrom-Json -AsHashtable
    } catch { $rejected.reason='trace_unreadable_or_partial'; return $rejected }
    if ($header.event -ne 'capture_started' -or $header.schema -ne 1 -or $header.pid -ne $GamePid -or
        $header.debug_build -isnot [bool] -or $header.debug_build -or [string]::IsNullOrWhiteSpace($header.session) -or
        $row.schema -ne 1 -or $row.pid -ne $GamePid -or $row.session -ne $header.session) {
        $rejected.reason='trace_identity_mismatch'; return $rejected
    }
    if ($row.event -ne 'sample' -or $row.phase -ne 'running' -or $row.screen -ne 'running' -or
        $row.focused -isnot [bool] -or -not $row.focused -or $row.run_number -lt 1 -or
        $row.window_width -ne 1920 -or $row.window_height -ne 1080) {
        $rejected.reason='not_focused_1080p_running'; return $rejected
    }
    $speed=0.0; $elapsed=0.0
    if (-not [double]::TryParse([string]$row.speed,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$speed) -or
        -not [double]::TryParse([string]$row.elapsed_usec,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$elapsed) -or
        -not [double]::IsFinite($speed) -or $speed -le 0 -or -not [double]::IsFinite($elapsed) -or $elapsed -lt 0 -or
        -not [double]::IsFinite($GameUptimeSeconds) -or $GameUptimeSeconds -lt 0 -or
        -not [double]::IsFinite($CaptureStartUptimeSeconds) -or $CaptureStartUptimeSeconds -lt 0 -or $CaptureStartUptimeSeconds -gt $GameUptimeSeconds) {
        $rejected.reason='invalid_motion_or_clock'; return $rejected
    }
    # Trace creation anchors the capture clock after engine initialization.
    # Reject future or stale samples independently of slow engine startup;
    # never start from an old running row followed by a partial latest write.
    $age=$GameUptimeSeconds-$CaptureStartUptimeSeconds-$elapsed/1000000.0
    if ($age -lt 0 -or $age -gt 5) { $rejected.reason='stale_or_future_sample'; return $rejected }
    return @{ready=$true;reason='fresh_focused_1080p_driving';sample=$row}
}
