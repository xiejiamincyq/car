Add-Type -AssemblyName System.Drawing

$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$sourceRoot = Join-Path $workspace 'art\source\environment_sequences'
$outputRoot = Join-Path $workspace 'assets\environment_sequences'
$stripWidth = 256
$stripHeight = 5120
$segmentHeight = 1024
$segmentCount = 5

$tracks = @(
    @{
        Id = 'neon_coast'
        Sections = @('section_00.png', 'section_01.png', 'section_02.png', 'section_03.png', 'section_04.png')
        SectionRoot = 'neon_coast_sections'
        LeftRoadEdges = @(292.0, 293.0, 292.0, 293.0, 294.0)
        RightRoadEdges = @(726.0, 729.0, 727.0, 725.0, 724.0)
    },
    @{ Id = 'freight_harbor'; Source = 'freight_harbor_master.png'; LeftRoadEdge = 286.0; RightRoadEdge = 438.0 },
    @{ Id = 'storm_ridge'; Source = 'storm_ridge_master.png'; LeftRoadEdge = 319.0; RightRoadEdge = 480.0 },
    @{ Id = 'sunrise_express'; Source = 'sunrise_express_master.png'; LeftRoadEdge = 254.0; RightRoadEdge = 468.0 }
)

function New-SectionPanel {
    param(
        [System.Drawing.Bitmap]$Source,
        [double]$SourceX
    )

    $panel = [System.Drawing.Bitmap]::new($stripWidth, $segmentHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($panel)
    try {
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $destination = [System.Drawing.RectangleF]::new(0.0, 0.0, [float]$stripWidth, [float]$segmentHeight)
        $sourceRectangle = [System.Drawing.RectangleF]::new([float]$SourceX, 0.0, [float]$stripWidth, [float]$Source.Height)
        $graphics.DrawImage($Source, $destination, $sourceRectangle, [System.Drawing.GraphicsUnit]::Pixel)
    }
    finally {
        $graphics.Dispose()
    }
    return $panel
}

function Blend-SectionBoundaries {
    param([System.Collections.ArrayList]$Panels)

    $blendRows = 96
    for ($index = 0; $index -lt $Panels.Count - 1; $index++) {
        $lowerPanel = $Panels[$index]
        $upperPanel = $Panels[$index + 1]
        for ($offset = 0; $offset -lt $blendRows; $offset++) {
            $weight = 0.5 * (1.0 - $offset / [double]($blendRows - 1))
            $lowerY = $offset
            $upperY = $segmentHeight - 1 - $offset
            for ($x = 0; $x -lt $stripWidth; $x++) {
                $lowerColor = $lowerPanel.GetPixel($x, $lowerY)
                $upperColor = $upperPanel.GetPixel($x, $upperY)
                $lowerMixed = [System.Drawing.Color]::FromArgb(
                    255,
                    [int][Math]::Round($lowerColor.R * (1.0 - $weight) + $upperColor.R * $weight),
                    [int][Math]::Round($lowerColor.G * (1.0 - $weight) + $upperColor.G * $weight),
                    [int][Math]::Round($lowerColor.B * (1.0 - $weight) + $upperColor.B * $weight)
                )
                $upperMixed = [System.Drawing.Color]::FromArgb(
                    255,
                    [int][Math]::Round($upperColor.R * (1.0 - $weight) + $lowerColor.R * $weight),
                    [int][Math]::Round($upperColor.G * (1.0 - $weight) + $lowerColor.G * $weight),
                    [int][Math]::Round($upperColor.B * (1.0 - $weight) + $lowerColor.B * $weight)
                )
                $lowerPanel.SetPixel($x, $lowerY, $lowerMixed)
                $upperPanel.SetPixel($x, $upperY, $upperMixed)
            }
        }
    }
}

function Export-SectionPanels {
    param(
        [System.Collections.ArrayList]$Panels,
        [string]$TrackId,
        [string]$Side
    )

    $trackOutput = Join-Path $outputRoot $TrackId
    New-Item -ItemType Directory -Force -Path $trackOutput | Out-Null
    for ($index = 0; $index -lt $Panels.Count; $index++) {
        $filename = '{0}_{1:d2}.png' -f $Side, $index
        $Panels[$index].Save((Join-Path $trackOutput $filename), [System.Drawing.Imaging.ImageFormat]::Png)
    }
}

function Build-SectionSequence {
    param([hashtable]$Track)

    $leftPanels = [System.Collections.ArrayList]::new()
    $rightPanels = [System.Collections.ArrayList]::new()
    try {
        for ($index = 0; $index -lt $Track.Sections.Count; $index++) {
            $sourcePath = Join-Path (Join-Path $sourceRoot $Track.SectionRoot) $Track.Sections[$index]
            $source = [System.Drawing.Bitmap]::new($sourcePath)
            try {
                [void]$leftPanels.Add((New-SectionPanel -Source $source -SourceX ($Track.LeftRoadEdges[$index] - $stripWidth)))
                [void]$rightPanels.Add((New-SectionPanel -Source $source -SourceX $Track.RightRoadEdges[$index]))
            }
            finally {
                $source.Dispose()
            }
        }
        Blend-SectionBoundaries -Panels $leftPanels
        Blend-SectionBoundaries -Panels $rightPanels
        Export-SectionPanels -Panels $leftPanels -TrackId $Track.Id -Side 'left'
        Export-SectionPanels -Panels $rightPanels -TrackId $Track.Id -Side 'right'
    }
    finally {
        foreach ($panel in $leftPanels) { $panel.Dispose() }
        foreach ($panel in $rightPanels) { $panel.Dispose() }
    }
}

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
    if ($track.ContainsKey('Sections')) {
        Build-SectionSequence -Track $track
        continue
    }
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
