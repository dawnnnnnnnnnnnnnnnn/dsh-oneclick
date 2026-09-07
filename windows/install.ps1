# dsh one-click installer (Windows)
# Steps: install Node.js if missing -> download whale-girl icon -> create desktop shortcut -> launch dsh

$ErrorActionPreference = 'Stop'

# Whale-girl icon URLs, tried in order. To use a different icon, replace the
# first URL below and keep the single quotes around it.
# License: CC BY-NC-SA 4.0 (non-commercial use only)
$IconUrls = @(
  'https://cdn.jsdelivr.net/gh/fornarwhal/deepseek-whale-girl-icon@main/improved-1.png',
  'https://raw.githubusercontent.com/fornarwhal/deepseek-whale-girl-icon/main/improved-1.png',
  'https://cdn.jsdelivr.net/gh/fornarwhal/deepseek-whale-girl-icon@main/improved-2.png',
  'https://raw.githubusercontent.com/fornarwhal/deepseek-whale-girl-icon/main/improved-2.png'
)

$DataDir     = Join-Path $env:LOCALAPPDATA 'dsh-oneclick'
$IconPng     = Join-Path $DataDir 'dsh-icon.png'
$IconIco     = Join-Path $DataDir 'dsh-icon.ico'
$LauncherBat = Join-Path $DataDir 'start-dsh.bat'

# Allow older Windows PowerShell to reach HTTPS download links
try {
  [Net.ServicePointManager]::SecurityProtocol =
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

function Test-Node {
  if (Get-Command node -ErrorAction SilentlyContinue) { return $true }
  $nodeDir = Join-Path $env:ProgramFiles 'nodejs'
  if (Test-Path (Join-Path $nodeDir 'node.exe')) {
    $env:PATH = "$nodeDir;$env:PATH"
    return $true
  }
  return $false
}

function Convert-PngToIco {
  param([string]$PngPath, [string]$IcoPath)
  Add-Type -AssemblyName System.Drawing
  $src = [System.Drawing.Image]::FromFile($PngPath)
  $bmp = New-Object System.Drawing.Bitmap 256, 256
  $g   = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.DrawImage($src, 0, 0, 256, 256)
  $ms  = New-Object System.IO.MemoryStream
  $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
  $png = $ms.ToArray()
  $out = New-Object System.IO.MemoryStream
  $bw  = New-Object System.IO.BinaryWriter($out)
  $bw.Write([UInt16]0)                 # reserved
  $bw.Write([UInt16]1)                 # type: icon
  $bw.Write([UInt16]1)                 # one image
  $bw.Write([Byte]0)                   # width: 0 means 256
  $bw.Write([Byte]0)                   # height: 0 means 256
  $bw.Write([Byte]0)                   # palette
  $bw.Write([Byte]0)                   # reserved
  $bw.Write([UInt16]1)                 # planes
  $bw.Write([UInt16]32)                # bits per pixel
  $bw.Write([UInt32]$png.Length)       # data size
  $bw.Write([UInt32]22)                # data offset
  $bw.Write($png)                      # PNG data (Vista+ supports PNG-in-ICO)
  $bw.Flush()
  [System.IO.File]::WriteAllBytes($IcoPath, $out.ToArray())
  $bw.Dispose(); $out.Dispose(); $ms.Dispose(); $g.Dispose(); $bmp.Dispose(); $src.Dispose()
}

Write-Host '=============================================='
Write-Host '  dsh one-click installer'
Write-Host '=============================================='
Write-Host ''

# 1. Check / install Node.js
if (-not (Test-Node)) {
  Write-Host '[1/4] Node.js not found. Trying to install it with winget (this can take a few minutes)...'
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host 'winget is not available on this PC, so auto-install is not possible.'
    Write-Host 'Please download and install Node.js LTS from: https://nodejs.org/zh-cn/download'
    Write-Host 'Then run install-windows.bat again.'
    Read-Host 'Press Enter to exit'
    exit 1
  }
  winget install --id OpenJS.NodeJS.LTS -e --silent --accept-source-agreements --accept-package-agreements
  if (-not (Test-Node)) {
    Write-Host 'Auto-install did not succeed, or the system PATH has not refreshed yet.'
    Write-Host 'Please download and install Node.js LTS from: https://nodejs.org/zh-cn/download'
    Write-Host 'Then run install-windows.bat again.'
    Read-Host 'Press Enter to exit'
    exit 1
  }
}
Write-Host "[1/4] Node.js is ready: $(node -v)"

# 2. Download the whale-girl icon (optional; a failure here is not fatal)
Write-Host '[2/4] Preparing the desktop icon...'
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
$iconOk = $false
foreach ($url in $IconUrls) {
  try {
    Invoke-WebRequest -Uri $url -OutFile $IconPng -UseBasicParsing -TimeoutSec 30
    if ((Test-Path $IconPng) -and ((Get-Item $IconPng).Length -gt 0)) {
      $iconOk = $true
      Write-Host "Icon downloaded: $url"
      break
    }
  } catch {
    Write-Host "Try failed: $url  ($($_.Exception.Message))"
  }
}
if ($iconOk) {
  try {
    Convert-PngToIco -PngPath $IconPng -IcoPath $IconIco
  } catch {
    $iconOk = $false
  }
}
if (-not $iconOk) {
  Write-Host '(No icon downloaded; the desktop shortcut will use the default icon. This does not affect usage.)'
}

# 3. Create the desktop shortcut
Write-Host '[3/4] Creating the desktop shortcut...'
$launcher = @'
@echo off
set "PATH=%ProgramFiles%\nodejs;%PATH%"
where npx >nul 2>nul
if errorlevel 1 (
  echo [dsh] npx not found. Please install Node.js first: https://nodejs.org/zh-cn/download
  pause
  exit /b 1
)
echo Starting dsh web... close this window to stop dsh.
npx -y @deepseek-ai/dsh web
echo.
echo dsh has stopped. Press any key to close this window.
pause >nul
'@
Set-Content -Path $LauncherBat -Value $launcher -Encoding Ascii

$desktop = [Environment]::GetFolderPath('Desktop')
$lnkPath = Join-Path $desktop 'dsh.lnk'
$shell   = New-Object -ComObject WScript.Shell
$sc      = $shell.CreateShortcut($lnkPath)
$sc.TargetPath       = $LauncherBat
$sc.WorkingDirectory = $DataDir
$sc.Description      = 'Launch dsh (DeepSeek Harness)'
if ($iconOk -and (Test-Path $IconIco)) {
  $sc.IconLocation = "$IconIco,0"
}
$sc.Save()
Write-Host "Desktop shortcut created: $lnkPath"

# 4. Launch dsh
Write-Host '[4/4] Starting dsh web (your browser will open automatically)...'
Start-Process -FilePath $LauncherBat
Write-Host ''
Write-Host 'Done! To start dsh in the future, double-click the dsh icon on your desktop.'
