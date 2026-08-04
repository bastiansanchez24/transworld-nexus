#Requires -Version 5.1
<#
.SYNOPSIS
  Desinstala Nexus (instalación bootstrap en carpeta de usuario).

.PARAMETER ParentPid
  Si se indica (>0), espera a que ese proceso termine antes de borrar
  (flujo "Desinstalar" desde la app). Sin ParentPid, aborta si Nexus sigue abierto.
#>
[CmdletBinding()]
param(
  [string]$InstallDir = '',
  [int]$ParentPid = 0
)

$ErrorActionPreference = 'Stop'

$AppDisplayName = 'Nexus'
$UninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{E68BC201-9F31-48C7-9943-41A6673413E0}_is1'
$LegacyUninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{E68BC201-9F31-48C7-9943-41A6673413E0}'
$AppDataDir = Join-Path $env:APPDATA 'Transworld\Nexus'
$LegacyAppDataDir = Join-Path $env:APPDATA 'Transworld\Transworld Nexus'
$PendingPhotosDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'leads_pendientes'
$LogPath = Join-Path $env:TEMP 'nexus-uninstall.log'

if ([string]::IsNullOrWhiteSpace($InstallDir)) {
  $InstallDir = Join-Path $env:LOCALAPPDATA 'Nexus'
}

$LegacyInstallDir = Join-Path $env:LOCALAPPDATA 'Transworld NEXUS'
$StartMenuDirs = @(
  (Join-Path ([Environment]::GetFolderPath('Programs')) 'Nexus'),
  (Join-Path ([Environment]::GetFolderPath('Programs')) 'Transworld NEXUS')
)
$DesktopShortcutNames = @('Nexus.lnk', 'Transworld NEXUS.lnk')

function Write-Log {
  param([string]$Message)
  $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
  try { Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8 } catch { }
}

function Remove-DirectoryIfExists {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    Write-Log ('Omitido (no existe): ' + $Path)
    return
  }
  Write-Log ('Eliminando: ' + $Path)
  Remove-Item -LiteralPath $Path -Recurse -Force
}

function Remove-ShortcutIfExists {
  param([string]$Path)
  if (Test-Path -LiteralPath $Path) {
    Write-Log ('Eliminando acceso directo: ' + $Path)
    Remove-Item -LiteralPath $Path -Force
  }
}

function Test-FileUnlocked([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $true }
  try {
    $fs = [System.IO.File]::Open(
      $Path,
      [System.IO.FileMode]::Open,
      [System.IO.FileAccess]::ReadWrite,
      [System.IO.FileShare]::None
    )
    $fs.Close()
    return $true
  } catch {
    return $false
  }
}

function Wait-NexusClosed {
  param([int]$WaitPid)

  if ($WaitPid -gt 0) {
    try {
      $parent = Get-Process -Id $WaitPid -ErrorAction SilentlyContinue
      if ($parent) {
        Write-Log ('Esperando cierre del proceso ' + $WaitPid + '...')
        $null = $parent.WaitForExit(180000)
      } else {
        Write-Log ('Proceso padre ' + $WaitPid + ' ya no existe.')
      }
    } catch {
      Write-Log ('Aviso esperando el proceso padre: ' + $_.Exception.Message)
    }
  }

  $exeCandidates = @(
    (Join-Path $InstallDir 'transworld_nexus.exe'),
    (Join-Path $LegacyInstallDir 'transworld_nexus.exe')
  )
  $deadline = (Get-Date).AddSeconds(180)
  while ((Get-Date) -lt $deadline) {
    $locked = $false
    foreach ($exe in $exeCandidates) {
      if (-not (Test-FileUnlocked $exe)) { $locked = $true; break }
    }
    if (-not $locked) { break }
    Start-Sleep -Milliseconds 500
  }

  foreach ($exe in $exeCandidates) {
    if (-not (Test-FileUnlocked $exe)) {
      throw 'Los archivos de instalacion siguen bloqueados tras 180s.'
    }
  }

  Start-Sleep -Milliseconds 800
}

Write-Log '--- Inicio de desinstalacion ---'
Write-Host "Desinstalando $AppDisplayName..." -ForegroundColor Cyan

try {
  if ($ParentPid -gt 0) {
    Wait-NexusClosed -WaitPid $ParentPid
  } else {
    foreach ($dir in @($InstallDir, $LegacyInstallDir)) {
      $exePath = Join-Path $dir 'transworld_nexus.exe'
      if (Test-Path -LiteralPath $exePath) {
        $proc = Get-Process -Name 'transworld_nexus' -ErrorAction SilentlyContinue
        if ($proc) {
          Write-Host 'Cierra Nexus antes de desinstalar.' -ForegroundColor Yellow
          Write-Log 'Abortado: proceso transworld_nexus en ejecucion'
          exit 1
        }
      }
    }
  }

  foreach ($startMenuDir in $StartMenuDirs) {
    Remove-ShortcutIfExists (Join-Path $startMenuDir "$AppDisplayName.lnk")
    Remove-ShortcutIfExists (Join-Path $startMenuDir 'Transworld NEXUS.lnk')
    if (Test-Path -LiteralPath $startMenuDir) {
      Remove-Item -LiteralPath $startMenuDir -Force -Recurse -ErrorAction SilentlyContinue
    }
  }

  $desktop = [Environment]::GetFolderPath('Desktop')
  foreach ($name in $DesktopShortcutNames) {
    Remove-ShortcutIfExists (Join-Path $desktop $name)
  }

  Remove-DirectoryIfExists $AppDataDir
  Remove-DirectoryIfExists $LegacyAppDataDir
  Remove-DirectoryIfExists $PendingPhotosDir
  Remove-DirectoryIfExists $InstallDir
  Remove-DirectoryIfExists $LegacyInstallDir

  if (Test-Path -LiteralPath $UninstallKey) {
    Write-Log 'Eliminando entrada del registro de desinstalacion'
    Remove-Item -LiteralPath $UninstallKey -Recurse -Force
  }
  if (Test-Path -LiteralPath $LegacyUninstallKey) {
    Remove-Item -LiteralPath $LegacyUninstallKey -Recurse -Force
  }

  Write-Host "$AppDisplayName desinstalado." -ForegroundColor Green
  Write-Log 'Desinstalacion completada'
  exit 0
} catch {
  Write-Host $_.Exception.Message -ForegroundColor Red
  Write-Host "Log: $LogPath" -ForegroundColor DarkGray
  Write-Log ('ERROR: ' + $_.Exception.Message)
  exit 1
}
