# Genera assets\tray.ico (16/24/32/48/256, 32 bits con alfa) y assets\tray-preview.png
# Diseno: "Segunda pantalla" - rectangulo apaisado redondeado (iPhone en landscape)
# con un cuadrado verde adentro (indicador WhatsApp encendido).
#
# Uso (Windows PowerShell 5.1, sin dependencias):
#   powershell -ExecutionPolicy Bypass -File tools\make-icon.ps1
#
# Cada tamano se renderiza por separado con geometria propia (bordes enteros en px,
# cuadrado verde alineado a la grilla) - no se reescala el de 256.

$ErrorActionPreference = 'Stop'
$root      = Split-Path -Parent $PSScriptRoot
$assetsDir = Join-Path $root 'assets'
if (-not (Test-Path $assetsDir)) { New-Item -ItemType Directory -Path $assetsDir | Out-Null }
$icoPath     = Join-Path $assetsDir 'tray.ico'
$previewPath = Join-Path $assetsDir 'tray-preview.png'

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public class IconSpec {
    public int Size;            // canvas cuadrado
    public double X, Y, W, H;   // rectangulo exterior (borde incluido)
    public double Border;       // grosor del borde en px
    public double Radius;       // radio de esquina exterior
    public double GX, GY, GS;   // cuadrado verde (x, y, lado)
    public double GRadius;      // radio del cuadrado verde
}

public static class IconRender {
    // colores (R,G,B)
    static readonly int[] Fill   = { 0x2B, 0x2F, 0x36 };
    static readonly int[] Line   = { 0xE6, 0xED, 0xF3 };
    static readonly int[] Green  = { 0x25, 0xD3, 0x66 };

    static bool Inside(double px, double py, double x, double y, double w, double h, double r) {
        if (px < x || px > x + w || py < y || py > y + h) return false;
        double cx = Math.Min(Math.Max(px, x + r), x + w - r);
        double cy = Math.Min(Math.Max(py, y + r), y + h - r);
        double dx = px - cx, dy = py - cy;
        return dx * dx + dy * dy <= r * r;
    }

    public static Bitmap Render(IconSpec s) {
        int n = s.Size;
        int ss = n >= 128 ? 4 : 8;   // supersampling por eje
        Bitmap bmp = new Bitmap(n, n, PixelFormat.Format32bppArgb);
        byte[] buf = new byte[n * n * 4];
        double bi = s.Border, ri = Math.Max(0, s.Radius - s.Border);
        for (int py = 0; py < n; py++) {
            for (int px = 0; px < n; px++) {
                double sa = 0, sr = 0, sg = 0, sb = 0;
                for (int j = 0; j < ss; j++) {
                    for (int i = 0; i < ss; i++) {
                        double fx = px + (i + 0.5) / ss, fy = py + (j + 0.5) / ss;
                        int[] c = null;
                        if (Inside(fx, fy, s.GX, s.GY, s.GS, s.GS, s.GRadius)) c = Green;
                        else if (Inside(fx, fy, s.X + bi, s.Y + bi, s.W - 2 * bi, s.H - 2 * bi, ri)) c = Fill;
                        else if (Inside(fx, fy, s.X, s.Y, s.W, s.H, s.Radius)) c = Line;
                        if (c != null) { sa += 1; sr += c[0]; sg += c[1]; sb += c[2]; }
                    }
                }
                int o = (py * n + px) * 4;
                if (sa > 0) {
                    buf[o + 0] = (byte)Math.Round(sb / sa);
                    buf[o + 1] = (byte)Math.Round(sg / sa);
                    buf[o + 2] = (byte)Math.Round(sr / sa);
                    buf[o + 3] = (byte)Math.Round(255.0 * sa / (ss * ss));
                }
            }
        }
        BitmapData bd = bmp.LockBits(new Rectangle(0, 0, n, n), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        Marshal.Copy(buf, 0, bd.Scan0, buf.Length);
        bmp.UnlockBits(bd);
        return bmp;
    }
}
'@

function New-Spec($size, $x, $y, $w, $h, $border, $radius, $gs, $gradius) {
    $s = New-Object IconSpec
    $s.Size = $size; $s.X = $x; $s.Y = $y; $s.W = $w; $s.H = $h
    $s.Border = $border; $s.Radius = $radius
    $s.GS = $gs; $s.GRadius = $gradius
    # cuadrado verde centrado en el rectangulo, redondeado a la grilla de pixeles
    $s.GX = [math]::Floor($x + ($w - $gs) / 2)
    $s.GY = [math]::Floor($y + ($h - $gs) / 2)
    return $s
}

# Geometria por tamano: size, x, y, w, h, borde, radio, lado verde, radio verde
$specs = @(
    (New-Spec  16  0   3  16  10  1   2.5   6  1.0),
    (New-Spec  24  0   5  24  14  1   3.5   8  1.0),
    (New-Spec  32  0   7  32  18  2   5     10 2.0),
    (New-Spec  48  0  10  48  28  2   7     16 3.0),
    (New-Spec 256  0  56 256 144  8  28     76 14.0)
)

# --- Render + frames PNG ---
$frames = @()
$bitmaps = @{}
foreach ($s in $specs) {
    $bmp = [IconRender]::Render($s)
    $bitmaps[$s.Size] = $bmp
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $frames += ,@{ Size = $s.Size; Data = $ms.ToArray() }
    $ms.Dispose()
}

# --- Escribir .ico a mano: ICONDIR + ICONDIRENTRY[] + frames PNG ---
$out = New-Object System.IO.MemoryStream
$bw  = New-Object System.IO.BinaryWriter($out)
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$frames.Count)
$offset = 6 + 16 * $frames.Count
foreach ($f in $frames) {
    $dim = if ($f.Size -ge 256) { 0 } else { $f.Size }
    $bw.Write([byte]$dim); $bw.Write([byte]$dim)   # ancho, alto (0 = 256)
    $bw.Write([byte]0); $bw.Write([byte]0)         # paleta, reservado
    $bw.Write([uint16]1); $bw.Write([uint16]32)    # planes, bpp
    $bw.Write([uint32]$f.Data.Length)
    $bw.Write([uint32]$offset)
    $offset += $f.Data.Length
}
foreach ($f in $frames) { $bw.Write($f.Data) }
$bw.Flush()
[System.IO.File]::WriteAllBytes($icoPath, $out.ToArray())
$bw.Dispose()
Write-Host "OK: $icoPath ($((Get-Item $icoPath).Length) bytes)"

# --- Preview: 16/32/256 sobre fondo claro y oscuro, chicos ampliados con nearest-neighbor ---
Add-Type -AssemblyName System.Drawing
$W = 1300; $H = 440
$pv = New-Object System.Drawing.Bitmap($W, $H)
$g  = [System.Drawing.Graphics]::FromImage($pv)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::None
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
$font = New-Object System.Drawing.Font('Segoe UI', 10)

function Draw-Panel($x, $y, $w, $h, $bgHex, $fgHex) {
    $bg = [System.Drawing.ColorTranslator]::FromHtml($bgHex)
    $fg = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($fgHex))
    $b  = New-Object System.Drawing.SolidBrush $bg
    $g.FillRectangle($b, $x, $y, $w, $h)
    $cx = $x + 20
    # 16 px x8
    $g.DrawImage($bitmaps[16], $cx, $y + 40, 128, 128)
    $g.DrawString('16 px  x8', $font, $fg, $cx, $y + 176)
    # 32 px x4
    $g.DrawImage($bitmaps[32], $cx + 160, $y + 40, 128, 128)
    $g.DrawString('32 px  x4', $font, $fg, $cx + 160, $y + 176)
    # 256 px x1
    $g.DrawImage($bitmaps[256], $cx + 300, $y + 20, 256, 256)
    $g.DrawString('256 px  x1', $font, $fg, $cx + 300, $y + 280)
    # tamano real (1:1): 16, 24, 32, 48
    $rx = $cx; $ry = $y + 330
    $g.DrawString('tamano real 1:1 (16 / 24 / 32 / 48)', $font, $fg, $rx, $ry)
    $ix = $rx; $iy = $ry + 30
    foreach ($sz in 16, 24, 32, 48) {
        $g.DrawImage($bitmaps[$sz], $ix, $iy, $sz, $sz)
        $ix += $sz + 24
    }
    $b.Dispose(); $fg.Dispose()
}
Draw-Panel 0   0   ($W/2) $H '#F3F3F3' '#202020'
Draw-Panel ($W/2) 0 ($W/2) $H '#202020' '#F3F3F3'
$g.Dispose()
$pv.Save($previewPath, [System.Drawing.Imaging.ImageFormat]::Png)
$pv.Dispose()
foreach ($b in $bitmaps.Values) { $b.Dispose() }
Write-Host "OK: $previewPath"
