Add-Type -AssemblyName System.Drawing

# 1. 512x512 Play Store Simgesi
$srcPath = "c:\xampp\htdocs\yardimciogretmen\app\logo.png"
$iconPath = "c:\xampp\htdocs\yardimciogretmen\app\playstore_icon_512.png"
$featurePath = "c:\xampp\htdocs\yardimciogretmen\app\playstore_feature_graphic_1024x500.png"

$src = [System.Drawing.Bitmap]::FromFile($srcPath)
Write-Output "Original Size: $($src.Width)x$($src.Height)"

# 512x512 Icon
$icon = New-Object System.Drawing.Bitmap(512, 512)
$gIcon = [System.Drawing.Graphics]::FromImage($icon)
$gIcon.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gIcon.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$gIcon.Clear([System.Drawing.Color]::White)
$gIcon.DrawImage($src, 0, 0, 512, 512)
$icon.Save($iconPath, [System.Drawing.Imaging.ImageFormat]::Png)
$gIcon.Dispose()
$icon.Dispose()
Write-Output "Created: $iconPath (512x512)"

# 1024x500 Feature Graphic (Özellik Grafiği - Google Play Zorunlu Şartı)
$feat = New-Object System.Drawing.Bitmap(1024, 500)
$gFeat = [System.Drawing.Graphics]::FromImage($feat)
$gFeat.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gFeat.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

# Background gradient: modern brand gradient (#0A2540 to #1976D2)
$rect = New-Object System.Drawing.Rectangle(0, 0, 1024, 500)
$brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    [System.Drawing.ColorTranslator]::FromHtml("#0F2027"),
    [System.Drawing.ColorTranslator]::FromHtml("#203A43"),
    [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal
)
$gFeat.FillRectangle($brush, $rect)

# Draw Logo centered on the left
$logoSize = 340
$logoX = 80
$logoY = (500 - $logoSize) / 2
$gFeat.DrawImage($src, $logoX, $logoY, $logoSize, $logoSize)

# Draw Text
$fontTitle = New-Object System.Drawing.Font("Arial", 46, [System.Drawing.FontStyle]::Bold)
$fontSub = New-Object System.Drawing.Font("Arial", 22, [System.Drawing.FontStyle]::Regular)
$textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$subBrush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#80D8FF"))

$gFeat.DrawString("ÖğretmenCep", $fontTitle, $textBrush, 460, 180)
$gFeat.DrawString("Akıllı Öğretmen Asistanı", $fontSub, $subBrush, 465, 260)

$feat.Save($featurePath, [System.Drawing.Imaging.ImageFormat]::Png)

$gFeat.Dispose()
$feat.Dispose()
$src.Dispose()
Write-Output "Created: $featurePath (1024x500)"
