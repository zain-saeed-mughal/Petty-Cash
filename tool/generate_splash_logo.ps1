# Generates the Android/Flutter startup mark from vector shapes at 1024 px.
Add-Type -AssemblyName System.Drawing

function New-RoundedPath([single]$x, [single]$y, [single]$width, [single]$height, [single]$radius) {
  $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
  $diameter = $radius * 2
  $path.AddArc($x, $y, $diameter, $diameter, 180, 90)
  $path.AddArc($x + $width - $diameter, $y, $diameter, $diameter, 270, 90)
  $path.AddArc($x + $width - $diameter, $y + $height - $diameter, $diameter, $diameter, 0, 90)
  $path.AddArc($x, $y + $height - $diameter, $diameter, $diameter, 90, 90)
  $path.CloseFigure()
  return $path
}

$bitmap = [System.Drawing.Bitmap]::new(1024, 1024, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::Transparent)

$halo = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(35, 196, 181, 253))
$outer = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#8B5CF6'))
$inner = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#6D28D9'))
$white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
$stripe = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#DDD6FE'))
$clasp = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#A78BFA'))
$gold = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#F5D38C'))
$graphics.FillEllipse($halo, 126, 126, 772, 772)
$graphics.FillEllipse($outer, 187, 187, 650, 650)
$graphics.FillEllipse($inner, 207, 207, 610, 610)

$handle = New-RoundedPath 386 313 252 154 58
$handlePen = [System.Drawing.Pen]::new([System.Drawing.Color]::White, 29)
$graphics.DrawPath($handlePen, $handle)
$wallet = New-RoundedPath 295 388 434 328 74
$graphics.FillPath($white, $wallet)
$graphics.SetClip($wallet)
$graphics.FillRectangle($stripe, 295, 480, 434, 88)
$graphics.ResetClip()
$flap = New-RoundedPath 544 477 207 154 72
$graphics.FillPath($clasp, $flap)
$graphics.FillEllipse($white, 622, 527, 54, 54)

# One small highlight gives the mark depth without adding readable text inside
# the tightly masked Android 12 system icon.
$graphics.FillEllipse($gold, 724, 310, 21, 21)

$destination = Join-Path $PSScriptRoot '..\assets\splash_logo.png'
$bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
$gold.Dispose(); $clasp.Dispose(); $stripe.Dispose(); $white.Dispose()
$inner.Dispose(); $outer.Dispose(); $halo.Dispose(); $handlePen.Dispose()
$flap.Dispose(); $wallet.Dispose(); $handle.Dispose()
$graphics.Dispose(); $bitmap.Dispose()
