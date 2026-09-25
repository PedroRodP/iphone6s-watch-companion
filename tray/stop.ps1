# Stops a running Web Watch Companion (server + tray) and waits until it is gone.
# Used by the installer/uninstaller so files aren't locked; safe to run when
# nothing is running.

$root = Split-Path $PSScriptRoot -Parent
$port = (Get-Content (Join-Path $root 'config.json') -Raw | ConvertFrom-Json).port

try {
  Invoke-WebRequest -Uri "http://127.0.0.1:$port/shutdown" -Method Post -UseBasicParsing `
    -Headers @{ 'X-Watch-Companion' = '1' } -TimeoutSec 3 | Out-Null
} catch {}

# Anything still running out of this install directory (this script excluded).
function Get-Leftovers {
  Get-CimInstance Win32_Process |
    Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine.IndexOf($root, [StringComparison]::OrdinalIgnoreCase) -ge 0 -and $_.Name -match '^(node|powershell|wscript)\.exe$' }
}

# Graceful path first: the tray follows the server out within ~2s.
for ($i = 0; $i -lt 20 -and (Get-Leftovers); $i++) { Start-Sleep -Milliseconds 500 }

# Last resort so an upgrade/uninstall never fails on a locked file.
Get-Leftovers | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
