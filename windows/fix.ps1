# dsh repair tool (Windows)
# Fixes a blank / white DSH page caused by plugins that no longer match the installed dsh.
# Every action backs up the profile first, and option 5 restores that backup.
#
# Normal use: double-click fix-windows.bat
# Advanced:   powershell -NoProfile -ExecutionPolicy Bypass -File windows\fix.ps1 -Action status

param(
  [ValidateSet('menu', 'status', 'safe', 'update', 'uninstall', 'reset', 'restore')]
  [string]$Action = 'menu',
  [string]$DshHome = '',
  [string]$ProfileName = 'web',
  [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if ([string]::IsNullOrWhiteSpace($DshHome)) {
  if ($env:DSH_HOME) { $DshHome = $env:DSH_HOME } else { $DshHome = Join-Path $env:USERPROFILE '.dsh' }
}

$ProfilesDir  = Join-Path $DshHome 'profiles'
$ProfileDir   = Join-Path $ProfilesDir $ProfileName
$ManifestPath = Join-Path $ProfileDir 'package.json'
$PatchPath    = Join-Path $ProfileDir 'cordis.patch.yml'
$HomePatch    = Join-Path $DshHome 'cordis.patch.yml'
$BackupRoot   = Join-Path $ProfileDir 'repair-backups'
$Utf8NoBom    = New-Object System.Text.UTF8Encoding($false)
$InBox        = @('@deepseek-ai/dsh-base', '@deepseek-ai/dsh-web-app')

function Read-JsonFile([string]$Path) {
  $raw = Get-Content -Path $Path -Raw -Encoding UTF8
  if (-not $raw -or $raw.Trim().Length -eq 0) { return $null }
  return ($raw | ConvertFrom-Json)
}

function Save-JsonFile($Object, [string]$Path) {
  $json = $Object | ConvertTo-Json -Depth 20
  [System.IO.File]::WriteAllText($Path, $json, $Utf8NoBom)
}

function Get-Manifest {
  if (-not (Test-Path $ManifestPath)) { return $null }
  return (Read-JsonFile $ManifestPath)
}

function Get-DependencyNames($Manifest) {
  if ($null -eq $Manifest) { return @() }
  $prop = $Manifest.PSObject.Properties['dependencies']
  if ($null -eq $prop -or $null -eq $prop.Value) { return @() }
  return @($prop.Value.PSObject.Properties.Name)
}

function Get-ThirdPartyNames($Manifest) {
  return @(Get-DependencyNames $Manifest | Where-Object { $_ -notlike '@deepseek-ai/*' })
}

function Get-BundleNames($Manifest) {
  if ($null -eq $Manifest) { return @() }
  $prop = $Manifest.PSObject.Properties['dsh']
  if ($null -eq $prop -or $null -eq $prop.Value) { return @() }
  $prof = $prop.Value.PSObject.Properties['profile']
  if ($null -eq $prof -or $null -eq $prof.Value) { return @() }
  $bundles = $prof.Value.PSObject.Properties['bundles']
  if ($null -eq $bundles -or $null -eq $bundles.Value) { return @() }
  return @($bundles.Value)
}

# In-box bundles only: what the official UI needs to boot.
function Get-PlannedOfficialBundles($Manifest) {
  $result = @()
  foreach ($name in $InBox) { $result += $name }
  foreach ($name in (Get-BundleNames $Manifest)) {
    if (($name -like '@deepseek-ai/*') -and ($result -notcontains $name)) { $result += $name }
  }
  return $result
}

# Does this installed package ship a profile patch (i.e. is it a bundle)?
function Test-BundleDeclared([string]$Name) {
  $pkgJson = Join-Path (Join-Path (Join-Path $ProfileDir 'node_modules') ($Name -replace '/', '\')) 'package.json'
  if (-not (Test-Path $pkgJson)) { return $false }
  try {
    $pkg = Read-JsonFile $pkgJson
    if ($null -eq $pkg.dsh.bundle.patch) { return $false }
    return $true
  } catch {
    return $false
  }
}

# Mirror what `dsh plugin` does: bundles = in-box + every installed dependency that declares dsh.bundle.
function Repair-BundlesList {
  $m = Get-Manifest
  if ($null -eq $m) { return }
  $list = @()
  foreach ($name in $InBox) { $list += $name }
  foreach ($name in (Get-DependencyNames $m)) {
    if ($name -like '@deepseek-ai/*') { continue }
    if ((Test-BundleDeclared $name) -and ($list -notcontains $name)) { $list += $name }
  }
  Set-Bundles $m $list
  Save-JsonFile $m $ManifestPath
}

function Set-Bundles($Manifest, [string[]]$Names) {
  if (-not ($Manifest.PSObject.Properties.Name -contains 'dsh')) {
    $Manifest | Add-Member -MemberType NoteProperty -Name 'dsh' -Value ([pscustomobject]@{})
  }
  if (-not ($Manifest.dsh.PSObject.Properties.Name -contains 'profile')) {
    $Manifest.dsh | Add-Member -MemberType NoteProperty -Name 'profile' -Value ([pscustomobject]@{})
  }
  $Manifest.dsh.profile | Add-Member -MemberType NoteProperty -Name 'bundles' -Value $Names -Force
}

function Clear-PatchLayers {
  foreach ($p in @($PatchPath, $HomePatch)) {
    if (-not (Test-Path $p)) { continue }
    $raw = Get-Content -Path $p -Raw -Encoding UTF8
    if ($raw -and ($raw.Trim() -ne '[]')) {
      [System.IO.File]::WriteAllText($p, "[]`n", $Utf8NoBom)
      Write-Host "  cleared patch layer: $p"
    }
  }
}

function New-Backup([string]$Tag) {
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $dir = Join-Path $BackupRoot "$stamp-$Tag"
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $pairs = @(
    @{ Src = $ManifestPath; Name = 'profile-package.json' },
    @{ Src = $PatchPath;    Name = 'profile-cordis.patch.yml' },
    @{ Src = $HomePatch;    Name = 'home-cordis.patch.yml' },
    @{ Src = (Join-Path $ProfileDir 'pnpm-lock.yaml'); Name = 'pnpm-lock.yaml' }
  )
  foreach ($pair in $pairs) {
    if (Test-Path $pair.Src) { Copy-Item -Path $pair.Src -Destination (Join-Path $dir $pair.Name) -Force }
  }
  Write-Host "  backup: $dir"
  return $dir
}

function Get-Backups {
  if (-not (Test-Path $BackupRoot)) { return @() }
  return @(Get-ChildItem -Path $BackupRoot -Directory | Sort-Object Name -Descending)
}

function Invoke-Restore([string]$Dir) {
  $map = @{
    'profile-package.json'     = $ManifestPath
    'profile-cordis.patch.yml' = $PatchPath
    'home-cordis.patch.yml'    = $HomePatch
    'pnpm-lock.yaml'           = (Join-Path $ProfileDir 'pnpm-lock.yaml')
  }
  $restored = 0
  foreach ($name in @($map.Keys)) {
    $src = Join-Path $Dir $name
    if (Test-Path $src) {
      Copy-Item -Path $src -Destination $map[$name] -Force
      Write-Host "  restored: $name"
      $restored++
    }
  }
  if ($restored -eq 0) { Write-Host "  nothing to restore in $Dir" }
}

function Invoke-Pnpm([string[]]$PnpmArgs) {
  if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
    Write-Host '  pnpm is not on PATH. Install it with: npm i -g pnpm'
    return $false
  }
  if (-not (Test-Path $ProfileDir)) {
    Write-Host "  profile directory not found: $ProfileDir"
    return $false
  }
  Push-Location $ProfileDir
  try {
    & pnpm @PnpmArgs
    $code = $LASTEXITCODE
  } finally {
    Pop-Location
  }
  if ($code -ne 0) {
    Write-Host "  pnpm exited with code $code"
    return $false
  }
  return $true
}

function Confirm-Step([string]$Question) {
  if ($Yes) { return $true }
  $answer = Read-Host "  $Question [y/N]"
  return ($answer -match '^(y|Y|yes|YES)$')
}

function Show-Status {
  Write-Host "DSH home    : $DshHome"
  Write-Host "profile dir : $ProfileDir"
  if (-not (Test-Path $ManifestPath)) {
    Write-Host 'state       : profile not initialized yet (no package.json)'
    return
  }
  $m = Get-Manifest
  $third = @(Get-ThirdPartyNames $m)
  $bundles = @(Get-BundleNames $m)
  $safe = @(Get-PlannedOfficialBundles $m)
  if ($third.Count -eq 0) {
    Write-Host 'plugins     : none (no third-party dependency)'
  } else {
    Write-Host ("plugins     : " + ($third -join ', '))
  }
  if ($bundles.Count -eq 0) {
    Write-Host 'bundles     : (empty)'
  } else {
    Write-Host ("bundles     : " + ($bundles -join ', '))
  }
  Write-Host ("safe mode   : " + ($safe -join ', '))
  foreach ($p in @($PatchPath, $HomePatch)) {
    if (Test-Path $p) {
      $raw = Get-Content -Path $p -Raw -Encoding UTF8
      $state = 'empty'
      if ($raw -and ($raw.Trim() -ne '[]')) { $state = 'has custom entries' }
      Write-Host "patch layer : $p -> $state"
    }
  }
  $backups = @(Get-Backups)
  Write-Host "backups     : $($backups.Count)"
}

function Invoke-SafeMode {
  $m = Get-Manifest
  if ($null -eq $m) { Write-Host "  no profile manifest at $ManifestPath"; return }
  $plan = Get-PlannedOfficialBundles $m
  $dropped = @(Get-BundleNames $m | Where-Object { $_ -notlike '@deepseek-ai/*' })
  New-Backup 'safe-mode' | Out-Null
  Set-Bundles $m $plan
  Save-JsonFile $m $ManifestPath
  Clear-PatchLayers
  Write-Host ("  bundles now: " + ($plan -join ', '))
  if ($dropped.Count -gt 0) { Write-Host ("  disabled   : " + ($dropped -join ', ')) }
  Write-Host '  plugins stay installed and can be re-enabled later.'
}

function Invoke-UpdateAll {
  $m = Get-Manifest
  $third = @(Get-ThirdPartyNames $m)
  if ($third.Count -eq 0) { Write-Host '  no third-party plugin to update'; return }
  Write-Host ("  updating: " + ($third -join ', '))
  New-Backup 'update' | Out-Null
  $pnpmArgs = @('update') + $third
  if (Invoke-Pnpm $pnpmArgs) {
    Repair-BundlesList
    Write-Host '  update finished, bundle list re-synced.'
  }
}

function Invoke-UninstallAll {
  $m = Get-Manifest
  $third = @(Get-ThirdPartyNames $m)
  if ($third.Count -eq 0) { Write-Host '  no third-party plugin to remove'; return }
  Write-Host ("  removing: " + ($third -join ', '))
  New-Backup 'uninstall' | Out-Null
  $pnpmArgs = @('remove') + $third
  if (Invoke-Pnpm $pnpmArgs) {
    Repair-BundlesList
    Clear-PatchLayers
    Write-Host '  all third-party plugins removed, official bundles only.'
  }
}

function Invoke-Reset {
  if (-not (Test-Path $ProfileDir)) { Write-Host "  profile directory not found: $ProfileDir"; return }
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $moved = "$ProfileDir.broken-$stamp"
  try {
    Rename-Item -Path $ProfileDir -NewName (Split-Path $moved -Leaf) -ErrorAction Stop
    Write-Host "  profile moved aside -> $moved"
    Write-Host '  the next "dsh web" run rebuilds it from the official template.'
    Write-Host '  conversation history and credentials are stored outside the profile and are kept.'
  } catch {
    Write-Host "  could not move the profile: $($_.Exception.Message)"
    Write-Host '  close the dsh web window (and any npm/pnpm window), then run this again.'
  }
}

function Invoke-RestoreMenu {
  $backups = @(Get-Backups)
  if ($backups.Count -eq 0) { Write-Host '  no backup found yet'; return }
  $i = 1
  foreach ($b in $backups) { Write-Host "  $i) $($b.Name)"; $i++ }
  $pick = Read-Host "  restore which backup? [1 = newest, Enter = cancel]"
  if ([string]::IsNullOrWhiteSpace($pick)) { return }
  $index = 0
  if (-not [int]::TryParse($pick, [ref]$index)) { Write-Host '  not a number, cancelled'; return }
  if ($index -lt 1 -or $index -gt $backups.Count) { Write-Host '  out of range, cancelled'; return }
  Invoke-Restore $backups[$index - 1].FullName
}

function Show-Menu {
  Write-Host ''
  Write-Host 'What do you want to do?'
  Write-Host '  1) Safe mode      - disable all third-party plugins (fastest fix, keeps them installed)'
  Write-Host '  2) Reset profile  - move the web profile aside, dsh rebuilds it from the official template'
  Write-Host '  3) Update plugins - update every third-party plugin to its latest version (needs network)'
  Write-Host '  4) Uninstall all  - remove every third-party plugin from the profile'
  Write-Host '  5) Restore backup - put back the profile files saved by this tool'
  Write-Host '  0) Exit'
  Write-Host ''
}

Write-Host '=============================================='
Write-Host '  dsh repair tool (blank / white page fix)'
Write-Host '=============================================='
Write-Host ''
Write-Host 'Close the dsh web window before you continue.'
Write-Host 'This tool edits your dsh profile; every action backs it up first.'
Write-Host ''
Show-Status

function Invoke-Action([string]$Name) {
  switch ($Name) {
    'status'    { return }
    'safe'      { Invoke-SafeMode }
    'update'    { Invoke-UpdateAll }
    'uninstall' { Invoke-UninstallAll }
    'reset'     { Invoke-Reset }
    'restore'   {
      $backups = @(Get-Backups)
      if ($backups.Count -eq 0) { Write-Host '  no backup found yet'; return }
      Invoke-Restore $backups[0].FullName
    }
  }
}

if ($Action -ne 'menu') {
  Write-Host ''
  Write-Host "action: $Action"
  Invoke-Action $Action
  Write-Host ''
  Write-Host 'Done. Start dsh web again (double-click the dsh icon on your desktop).'
  exit 0
}

$running = $true
while ($running) {
  Show-Menu
  $choice = Read-Host 'Choose'
  Write-Host ''
  switch ($choice) {
    '1' {
      if (Confirm-Step 'Disable every third-party plugin now?') { Invoke-Action 'safe' }
    }
    '2' {
      if (Confirm-Step 'Move the web profile aside and let dsh rebuild it?') { Invoke-Action 'reset' }
    }
    '3' {
      if (Confirm-Step 'Update every third-party plugin now?') { Invoke-Action 'update' }
    }
    '4' {
      if (Confirm-Step 'Remove every third-party plugin now?') { Invoke-Action 'uninstall' }
    }
    '5' { Invoke-RestoreMenu }
    '0' { $running = $false }
    default { Write-Host 'Please type 0-5.' }
  }
  if ($running) {
    Write-Host ''
    Write-Host 'After any change: close this window, then start dsh web again.'
    Write-Host 'If the page is still blank, run this tool again and try option 2 (Reset profile).'
  }
}

Write-Host ''
Write-Host 'Bye.'
