param(
    [ValidateSet("xingkai", "shuti", "mingxing", "mingshu")]
    [string]$Variant = "xingkai"
)

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$output = Join-Path $root "output\app-icon"
New-Item -ItemType Directory -Force -Path $output | Out-Null

$fontFile = if ($Variant -in @("xingkai", "mingxing")) {
    "C:\Windows\Fonts\STXINGKA.TTF"
} else {
    "C:\Windows\Fonts\FZSTK.TTF"
}

$fonts = New-Object System.Drawing.Text.PrivateFontCollection
$fonts.AddFontFile($fontFile)
$family = $fonts.Families[0]

$size = 1024
$bitmap = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

$background = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 151, 37, 31))
$graphics.FillRectangle($background, 0, 0, $size, $size)

$random = New-Object System.Random(271)
for ($i = 0; $i -lt 3600; $i++) {
    $x = $random.Next(0, $size)
    $y = $random.Next(0, $size)
    $diameter = $random.Next(1, 4)
    $alpha = $random.Next(4, 13)
    $grain = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($alpha, 255, 228, 198))
    $graphics.FillEllipse($grain, $x, $y, $diameter, $diameter)
    $grain.Dispose()
}

$vignettePath = New-Object System.Drawing.Drawing2D.GraphicsPath
$vignettePath.AddEllipse(-180, -210, 1380, 1380)
$vignetteBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush($vignettePath)
$vignetteBrush.CenterColor = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
$vignetteBrush.SurroundColors = @([System.Drawing.Color]::FromArgb(22, 70, 8, 6))
$graphics.FillRectangle($vignetteBrush, 0, 0, $size, $size)

function Add-CalligraphyCharacter {
    param(
        [string]$Text,
        [float]$EmSize,
        [float]$TargetX,
        [float]$TargetY,
        [float]$Rotation,
        [System.Drawing.FontFamily]$Family,
        [System.Drawing.Graphics]$Graphics
    )

    $format = [System.Drawing.StringFormat]::GenericTypographic
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddString($Text, $Family, [int][System.Drawing.FontStyle]::Regular, $EmSize, [System.Drawing.PointF]::new(0, 0), $format)
    $bounds = $path.GetBounds()
    $matrix = New-Object System.Drawing.Drawing2D.Matrix
    $matrix.Translate($TargetX - $bounds.X, $TargetY - $bounds.Y)
    $matrix.RotateAt($Rotation, [System.Drawing.PointF]::new($TargetX + $bounds.Width / 2, $TargetY + $bounds.Height / 2))
    $path.Transform($matrix)

    $shadowMatrix = New-Object System.Drawing.Drawing2D.Matrix
    $shadowMatrix.Translate(9, 12)
    $shadowPath = $path.Clone()
    $shadowPath.Transform($shadowMatrix)
    $shadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(86, 57, 8, 6))
    $Graphics.FillPath($shadowBrush, $shadowPath)

    $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 247, 229, 199))
    $Graphics.FillPath($textBrush, $path)

    $textBrush.Dispose()
    $shadowBrush.Dispose()
    $shadowPath.Dispose()
    $shadowMatrix.Dispose()
    $matrix.Dispose()
    $path.Dispose()
}

if ($Variant -eq "xingkai") {
    Add-CalligraphyCharacter "大" 500 238 92 -7 $family $graphics
    Add-CalligraphyCharacter "明" 468 340 466 4 $family $graphics
} elseif ($Variant -eq "shuti") {
    Add-CalligraphyCharacter "大" 510 205 85 -9 $family $graphics
    Add-CalligraphyCharacter "明" 480 330 464 6 $family $graphics
} elseif ($Variant -eq "mingxing") {
    Add-CalligraphyCharacter "明" 850 218 174 -5 $family $graphics
} else {
    Add-CalligraphyCharacter "明" 790 170 156 -7 $family $graphics
}

$master = Join-Path $output "daming-icon-$Variant-1024.png"
$bitmap.Save($master, [System.Drawing.Imaging.ImageFormat]::Png)

$graphics.Dispose()
$bitmap.Dispose()
$background.Dispose()
$vignetteBrush.Dispose()
$vignettePath.Dispose()
$fonts.Dispose()

Write-Output $master
