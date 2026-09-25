# Builds dist\WebWatchCompanion-Setup-<version>.exe.
#
# 1. Stages a self-contained copy of the app under dist\stage: the app files,
#    production-only node_modules, and the node.exe used to build (so the native
#    better-sqlite3 binary always matches the bundled runtime).
# 2. Compiles installer\setup.iss with Inno Setup.
#
# Requires Inno Setup 6 (ISCC.exe) on the build machine; end users need nothing.

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$dist = Join-Path $root 'dist'
$stage = Join-Path $dist 'stage'
$version = (Get-Content (Join-Path $root 'package.json') -Raw | ConvertFrom-Json).version

# ── Find the tools ────────────────────────────────────────────────────────────
$candidates = @(
  (Get-Command ISCC.exe -ErrorAction SilentlyContinue).Source,
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { $_ -and (Test-Path $_) }
$iscc = $candidates | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup 6 not found (ISCC.exe). Install it first: winget install JRSoftware.InnoSetup' }

$node = (Get-Command node -ErrorAction Stop).Source

# ── Stage ─────────────────────────────────────────────────────────────────────
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null

foreach ($item in 'server.js', 'config.json', 'package.json', 'package-lock.json', 'public', 'tray', 'assets') {
  Copy-Item (Join-Path $root $item) $stage -Recurse -Force
}
Remove-Item (Join-Path $stage 'assets\tray-preview.png') -ErrorAction SilentlyContinue

# --ignore-scripts: better-sqlite3 ships its Windows binary in prebuilds/, but
# installing from the lockfile makes npm try a node-gyp compile (no Python/VS
# here). The only script we need, copying NoSleep.js, is done by hand.
Push-Location $stage
try {
  & npm.cmd ci --omit=dev --ignore-scripts --no-audit --no-fund
  if ($LASTEXITCODE -ne 0) { throw 'npm ci failed' }
} finally { Pop-Location }
Copy-Item (Join-Path $stage 'node_modules\nosleep.js\dist\NoSleep.min.js') (Join-Path $stage 'public\NoSleep.min.js') -Force
# Not needed at runtime once installed.
Remove-Item (Join-Path $stage 'package-lock.json') -Force

# Slim down better-sqlite3: keep only the Windows x64 binary (the bundled node.exe
# is x64), drop the SQLite/C++ sources that are only used for compiling.
$bs = Join-Path $stage 'node_modules\better-sqlite3'
Get-ChildItem (Join-Path $bs 'prebuilds') -Filter '*.node' | Where-Object Name -ne 'win32-x64.node' | Remove-Item
Remove-Item (Join-Path $bs 'deps'), (Join-Path $bs 'src') -Recurse -Force -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Force (Join-Path $stage 'runtime') | Out-Null
Copy-Item $node (Join-Path $stage 'runtime\node.exe')

# Smoke test the staged app with the bundled runtime before packaging it.
$check = & (Join-Path $stage 'runtime\node.exe') -e "const D=require('better-sqlite3'); new D(':memory:').close(); require('express'); require('ws'); console.log('ok')" 2>&1
if ($check -ne 'ok') { throw "Staged app failed to load its dependencies: $check" }

# ── Compile ───────────────────────────────────────────────────────────────────
& $iscc "/DAppVersion=$version" (Join-Path $root 'installer\setup.iss')
if ($LASTEXITCODE -ne 0) { throw 'ISCC failed' }

Get-ChildItem $dist -Filter '*.exe' | ForEach-Object { '{0}  ({1:N1} MB)' -f $_.FullName, ($_.Length / 1MB) }
