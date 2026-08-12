Add-Type -AssemblyName System.Drawing

$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$sourceRoot = Join-Path $workspace 'art\source\environment_sequences'
$outputRoot = Join-Path $workspace 'assets\environment_sequences'
$stripWidth = 256
$stripHeight = 5120
$segmentHeight = 1024
$segmentCount = 5

$tracks = @(
    @{ Id = 'neon_coast'; Source = 'neon_coast_master.png'; LeftRoadEdge = 284.0; RightRoadEdge = 405.0 },
    @{ Id = 'freight_harbor'; Source = 'freight_harbor_master.png'; LeftRoadEdge = 286.0; RightRoadEdge = 438.0 },
    @{ Id = 'storm_ridge'; Source = 'storm_ridge_master.png'; LeftRoadEdge = 319.0; RightRoadEdge = 480.0 },
    @{ Id = 'sunrise_express'; Source = 'sunrise_express_master.png'; LeftRoadEdge = 254.0; RightRoadEdge = 468.0 }
)

function New-RouteStrip {
    param(
        [System.Drawing.Bitmap]$Source,
        [double]$SourceX,
        [double]$SourceWidth
    )

    $strip = [System.Drawing.Bitmap]::new($stripWidth, $stripHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($strip)
    try {
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $destination = [System.Drawing.RectangleF]::new(0.0, 0.0, [float]$stripWidth, [float]$stripHeight)
        $sourceRectangle = [System.Drawing.RectangleF]::new([float]$SourceX, 0.0, [float]$SourceWidth, [float]$Source.Height)
        $graphics.DrawImage($Source, $destination, $sourceRectangle, [System.Drawing.GraphicsUnit]::Pixel)
    }
    finally {
        $graphics.Dispose()
    }
    return $strip
}

function Export-RouteSegments {
    param(
        [System.Drawing.Bitmap]$Strip,
        [string]$TrackId,
        [string]$Side
    )

    $trackOutput = Join-Path $outputRoot $TrackId
    New-Item -ItemType Directory -Force -Path $trackOutput | Out-Null
    for ($index = 0; $index -lt $segmentCount; $index++) {
        # Cars travel from the bottom of the generated master toward its top.
        # Adjacent segments intentionally share one boundary row.
        $sourceY = ($stripHeight - $segmentHeight) - $index * ($segmentHeight - 1)
        $segment = [System.Drawing.Bitmap]::new($stripWidth, $segmentHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [System.Drawing.Graphics]::FromImage($segment)
        try {
            $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
            $graphics.DrawImage($Strip, 0, 0, [System.Drawing.Rectangle]::new(0, $sourceY, $stripWidth, $segmentHeight), [System.Drawing.GraphicsUnit]::Pixel)
        }
        finally {
            $graphics.Dispose()
        }
        try {
            $filename = '{0}_{1:d2}.png' -f $Side, $index
            $segment.Save((Join-Path $trackOutput $filename), [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $segment.Dispose()
        }
    }
}

foreach ($track in $tracks) {
    $sourcePath = Join-Path $sourceRoot $track.Source
    $source = [System.Drawing.Bitmap]::new($sourcePath)
    try {
        $scale = $stripHeight / [double]$source.Height
        $sourceWidth = $stripWidth / $scale
        $leftX = [Math]::Max(0.0, $track.LeftRoadEdge - $sourceWidth)
        $rightX = [Math]::Min($source.Width - $sourceWidth, $track.RightRoadEdge)
        $leftStrip = New-RouteStrip -Source $source -SourceX $leftX -SourceWidth $sourceWidth
        $rightStrip = New-RouteStrip -Source $source -SourceX $rightX -SourceWidth $sourceWidth
        try {
            Export-RouteSegments -Strip $leftStrip -TrackId $track.Id -Side 'left'
            Export-RouteSegments -Strip $rightStrip -TrackId $track.Id -Side 'right'
        }
        finally {
            $leftStrip.Dispose()
            $rightStrip.Dispose()
        }
    }
    finally {
        $source.Dispose()
    }
}

Write-Output "Generated $($tracks.Count * $segmentCount * 2) continuous environment segments in $outputRoot"
