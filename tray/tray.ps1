# System tray host for the Web Watch Companion server.
#
# Starts `node server.js` with no console window, puts an icon in the system
# tray, and offers a single right-click item ("Salir") that shuts the server
# down gracefully through POST /shutdown (so connected devices get
# `server_shutdown` and release NoSleep) instead of killing the process.
#
# Keep this file ASCII-only: Windows PowerShell 5.1 reads BOM-less files as ANSI.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$root = Split-Path $PSScriptRoot -Parent
$port = (Get-Content (Join-Path $root 'config.json') -Raw | ConvertFrom-Json).port
$title = 'Web Watch Companion'
$logDir = Join-Path $env:LOCALAPPDATA 'WebWatchCompanion\logs'

# Single instance: a second launch (e.g. autostart + Start Menu) exits quietly.
$mutex = New-Object System.Threading.Mutex($false, 'Local\WebWatchCompanionTray')
if (-not $mutex.WaitOne(0)) {
  # Launched by hand while already running: say so instead of doing nothing,
  # which looks like the shortcut is broken.
  [System.Windows.Forms.MessageBox]::Show('Ya esta en ejecucion. Buscalo en la bandeja del sistema (icono ^ si esta oculto).', $title, 'OK', 'Information') | Out-Null
  exit
}

# The installer ships its own node.exe under runtime\; running from a source
# checkout falls back to whatever node is on the PATH.
$node = Join-Path $root 'runtime\node.exe'
if (-not (Test-Path $node)) { $node = (Get-Command node -ErrorAction SilentlyContinue).Source }
if (-not $node) {
  [System.Windows.Forms.MessageBox]::Show('No se encontro node.exe.', $title, 'OK', 'Error') | Out-Null
  exit 1
}

# Nobody is watching a console, so keep the server output in files.
New-Item -ItemType Directory -Force $logDir | Out-Null
$proc = Start-Process -FilePath $node -ArgumentList 'server.js' -WorkingDirectory $root `
  -WindowStyle Hidden -PassThru `
  -RedirectStandardOutput (Join-Path $logDir 'server.out.log') `
  -RedirectStandardError (Join-Path $logDir 'server.err.log')
$null = $proc.Handle # cache the handle now, or ExitCode can come back empty later

$iconPath = Join-Path $root 'assets\tray.ico'
$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = if (Test-Path $iconPath) { New-Object System.Drawing.Icon($iconPath) } else { [System.Drawing.SystemIcons]::Application }
$notify.Text = "$title (puerto $port)"

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$exitItem = $menu.Items.Add('Salir')
$notify.ContextMenuStrip = $menu
$notify.Visible = $true

function Close-Tray {
  $notify.Visible = $false
  $notify.Dispose()
  $mutex.ReleaseMutex()
  [System.Windows.Forms.Application]::Exit()
}

$exitItem.add_Click({
  $timer.Stop()
  try {
    Invoke-WebRequest -Uri "http://127.0.0.1:$port/shutdown" -Method Post -UseBasicParsing `
      -Headers @{ 'X-Watch-Companion' = '1' } -TimeoutSec 3 | Out-Null
  } catch {}
  # Last resort only: the endpoint didn't work and the server is still up.
  if (-not $proc.WaitForExit(5000)) { $proc.Kill() }
  Close-Tray
})

# Watch the server: confirm startup, follow it out when it shuts down cleanly
# (exit code 0, e.g. stop.ps1 from the installer hit /shutdown), and bail out
# with an error when it dies on its own (e.g. port already taken) so we never
# leave a tray icon for a dead server.
$announced = $false
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2000
$timer.add_Tick({
  if ($proc.HasExited) {
    $timer.Stop()
    if ($proc.ExitCode -ne 0) {
      $notify.ShowBalloonTip(5000, $title, "El servidor se detuvo. Revisa server.err.log en $logDir", 'Error')
      Start-Sleep -Seconds 6
    }
    Close-Tray
  } elseif (-not $announced) {
    $script:announced = $true
    $notify.ShowBalloonTip(3000, $title, "Servidor activo en el puerto $port", 'Info')
  }
})
$timer.Start()

[System.Windows.Forms.Application]::Run()
