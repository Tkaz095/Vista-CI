Add-Type -AssemblyName System.Drawing

$sourcePath = Resolve-Path "mobile\assets\logo\logo.png"
$resPath = Resolve-Path "mobile\android\app\src\main\res"

Write-Host "Source: $sourcePath"
Write-Host "Res: $resPath"

$srcImage = [System.Drawing.Image]::FromFile($sourcePath)

function Resize-Image {
    param(
        [System.Drawing.Image]$Image,
        [int]$CanvasWidth,
        [int]$CanvasHeight,
        [int]$TargetWidth,
        [int]$TargetHeight,
        [string]$OutputPath,
        [System.Drawing.Color]$BackgroundColor = [System.Drawing.Color]::Transparent,
        [bool]$ClipCircle = $false
    )

    $bitmap = New-Object System.Drawing.Bitmap($CanvasWidth, $CanvasHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    if ($BackgroundColor -ne [System.Drawing.Color]::Transparent) {
        $brush = New-Object System.Drawing.SolidBrush($BackgroundColor)
        $g.FillRectangle($brush, 0, 0, $CanvasWidth, $CanvasHeight)
        $brush.Dispose()
    }

    if ($ClipCircle) {
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddEllipse(0, 0, $CanvasWidth, $CanvasHeight)
        $g.SetClip($path)
        $path.Dispose()
    }

    $offsetX = [int](($CanvasWidth - $TargetWidth) / 2)
    $offsetY = [int](($CanvasHeight - $TargetHeight) / 2)
    $g.DrawImage($Image, $offsetX, $offsetY, $TargetWidth, $TargetHeight)

    $g.Dispose()

    $dir = [System.IO.Path]::GetDirectoryName($OutputPath)
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    Write-Host "Generated: $OutputPath"
}

# 1. Density definitions
$densities = @(
    @{ Name = "mipmap-mdpi";   Legacy = 48;  Foreground = 108; SafeZone = 72;  Splash = 96 },
    @{ Name = "mipmap-hdpi";   Legacy = 72;  Foreground = 162; SafeZone = 108; Splash = 144 },
    @{ Name = "mipmap-xhdpi";  Legacy = 96;  Foreground = 216; SafeZone = 144; Splash = 192 },
    @{ Name = "mipmap-xxhdpi"; Legacy = 144; Foreground = 324; SafeZone = 216; Splash = 288 },
    @{ Name = "mipmap-xxxhdpi";Legacy = 192; Foreground = 432; SafeZone = 288; Splash = 384 }
)

foreach ($d in $densities) {
    $folder = Join-Path $resPath $d.Name

    # 1.1 Legacy ic_launcher.png (fit with small 4% padding for breathing room)
    $legacyTarget = [int]($d.Legacy * 0.94)
    $legacyPath = Join-Path $folder "ic_launcher.png"
    Resize-Image -Image $srcImage -CanvasWidth $d.Legacy -CanvasHeight $d.Legacy -TargetWidth $legacyTarget -TargetHeight $legacyTarget -OutputPath $legacyPath

    # 1.2 Round ic_launcher_round.png
    $roundPath = Join-Path $folder "ic_launcher_round.png"
    Resize-Image -Image $srcImage -CanvasWidth $d.Legacy -CanvasHeight $d.Legacy -TargetWidth $legacyTarget -TargetHeight $legacyTarget -OutputPath $roundPath -ClipCircle $true

    # 1.3 Adaptive foreground ic_launcher_foreground.png
    # The logo sits cleanly within the safe zone (around 68% of foreground canvas)
    $fgPath = Join-Path $folder "ic_launcher_foreground.png"
    Resize-Image -Image $srcImage -CanvasWidth $d.Foreground -CanvasHeight $d.Foreground -TargetWidth $d.SafeZone -TargetHeight $d.SafeZone -OutputPath $fgPath

    # 1.4 Splash logo for each density
    $splashPath = Join-Path $folder "splash_logo.png"
    Resize-Image -Image $srcImage -CanvasWidth $d.Splash -CanvasHeight $d.Splash -TargetWidth $d.Splash -TargetHeight $d.Splash -OutputPath $splashPath
}

# 1.5 Generate a drawable splash_logo.png (high-res 288x288)
$drawableSplash = Join-Path $resPath "drawable\splash_logo.png"
Resize-Image -Image $srcImage -CanvasWidth 288 -CanvasHeight 288 -TargetWidth 288 -TargetHeight 288 -OutputPath $drawableSplash

$srcImage.Dispose()
Write-Host "All icons generated successfully!"
