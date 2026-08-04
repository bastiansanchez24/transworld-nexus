#Requires -Version 5.1
<#
.SYNOPSIS
  Instalador bootstrap de Nexus para Windows.

.DESCRIPTION
  Consulta la última GitHub Release, descarga windows-NEXUS-vX.Y.Z.zip,
  extrae en %LOCALAPPDATA%\Nexus y crea accesos directos.
  No requiere recompilarse por versión: siempre instala el último release.

.PARAMETER Owner
  Owner del repositorio GitHub (default: bastiansanchez24).

.PARAMETER Repo
  Nombre del repositorio GitHub (default: transworld_project_nexus).

.PARAMETER InstallDir
  Carpeta de destino. Por defecto %LOCALAPPDATA%\Nexus
  (escribible sin admin, compatible con actualizaciones OTA).

.PARAMETER DesktopShortcut
  Crea un acceso directo en el escritorio.

.PARAMETER Launch
  Abre Nexus al finalizar la instalación.

.PARAMETER SkipSha256
  Omite la verificación SHA-256 del asset (solo depuración).

.PARAMETER SkipUninstallRegistry
  No registra la entrada de desinstalación (p. ej. cuando Inno Setup ya lo gestiona).
#>
[CmdletBinding()]
param(
  [string]$Owner = 'bastiansanchez24',
  [string]$Repo = 'transworld_project_nexus',
  [string]$InstallDir = '',
  [switch]$DesktopShortcut,
  [switch]$Launch = $true,
  [switch]$SkipSha256,
  [switch]$SkipUninstallRegistry
)

$ErrorActionPreference = 'Stop'

$ExeName = 'transworld_nexus.exe'
$AppDisplayName = 'Nexus'
$UninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{E68BC201-9F31-48C7-9943-41A6673413E0}'
$LogPath = Join-Path $env:TEMP 'nexus-install.log'
$UiTotalSteps = 6
$Script:UiStep = 0

if ([string]::IsNullOrWhiteSpace($InstallDir)) {
  $InstallDir = Join-Path $env:LOCALAPPDATA 'Nexus'
}

function Write-Log {
  param([string]$Message)
  $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
  try { Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8 } catch { }
}

function Format-Megabytes {
  param(
    [long]$Bytes,
    [int]$Decimals = 1
  )
  if ($Bytes -lt 0) { $Bytes = 0 }
  $mb = [math]::Round($Bytes / 1048576.0, $Decimals)
  return "$mb MB"
}

function Show-InstallBanner {
  Clear-Host
  Write-Host ''
  Write-Host '  ===============================================' -ForegroundColor Cyan
  Write-Host '              NEXUS - Instalador                 ' -ForegroundColor Cyan
  Write-Host '  ===============================================' -ForegroundColor Cyan
  Write-Host ''
  Write-UiDetail -Label 'Destino' -Value $InstallDir
  Write-Host ''
}

function Write-UiStep {
  param([string]$Message)
  $Script:UiStep++
  Write-Host ("  [{0}/{1}] {2}" -f $Script:UiStep, $UiTotalSteps, $Message) -ForegroundColor White
}

function Write-UiDetail {
  param(
    [string]$Label,
    [string]$Value
  )
  Write-Host ('       {0,-12}' -f ($Label + ':')) -NoNewline -ForegroundColor DarkGray
  Write-Host $Value
}

function Write-UiOk {
  param([string]$Message)
  Write-Host '       [OK] ' -NoNewline -ForegroundColor Green
  Write-Host $Message -ForegroundColor Green
}

function Write-UiWait {
  param([string]$Message)
  Write-Host '       ... ' -NoNewline -ForegroundColor DarkGray
  Write-Host $Message -ForegroundColor DarkGray
}

function Write-UserError {
  param([string]$Message)
  Write-Progress -Activity 'Instalando Nexus' -Completed -ErrorAction SilentlyContinue
  Write-Log "ERROR: $Message"
  Write-Host ''
  Write-Host '  [ERROR]' -ForegroundColor Red -NoNewline
  Write-Host " $Message"
}

function Start-UiProgress {
  param(
    [string]$Activity,
    [string]$Status,
    [int]$Percent = -1
  )
  Write-Progress -Activity $Activity -Status $Status -PercentComplete $Percent
}

function Stop-UiProgress {
  param([string]$Activity = 'Instalando Nexus')
  Write-Progress -Activity $Activity -Completed -ErrorAction SilentlyContinue
}

function Get-StrippedTag {
  param([string]$Tag)
  $t = $Tag.Trim()
  if ($t.StartsWith('v') -or $t.StartsWith('V')) { return $t.Substring(1) }
  return $t
}

function Resolve-NexusWindowsZipAsset {
  param($Release)

  $tag = Get-StrippedTag $Release.tag_name
  $exactName = "windows-NEXUS-v$tag.zip"

  # Solo windows-NEXUS-*.zip (excluye NexusBootstrap.zip y otros).
  $candidates = @(
    $Release.assets | Where-Object {
      $_.name -match '(?i)^windows-nexus-.+\.zip$'
    }
  )
  if ($candidates.Count -eq 0) { return $null }

  foreach ($c in $candidates) {
    if ($c.name -eq $exactName) { return $c }
  }

  return ($candidates | Sort-Object { [long]$_.size } -Descending | Select-Object -First 1)
}

function Get-ExpectedSha256Hex {
  param([string]$Digest)
  if ([string]::IsNullOrWhiteSpace($Digest)) { return $null }
  $trimmed = $Digest.Trim()
  if ($trimmed -match '(?i)^sha256:([0-9a-f]{64})$') {
    return $Matches[1].ToLowerInvariant()
  }
  if ($trimmed -match '(?i)^[0-9a-f]{64}$') {
    return $trimmed.ToLowerInvariant()
  }
  return $null
}

function Get-FileSha256Hex {
  param([string]$Path)
  $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
  return $hash.Hash.ToLowerInvariant()
}

function Test-DirectoryWritable {
  param([string]$DirPath)
  $probe = Join-Path $DirPath (".nexus-write-probe-" + [guid]::NewGuid().ToString())
  try {
    New-Item -ItemType Directory -Path $DirPath -Force | Out-Null
    Set-Content -LiteralPath $probe -Value 'ok' -Encoding ASCII
    return $true
  } catch {
    return $false
  } finally {
    Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
  }
}

function Copy-Payload {
  param(
    [string]$Source,
    [string]$Destination
  )
  $attempts = 0
  while ($true) {
    $attempts++
    try {
      Copy-Item -Path (Join-Path $Source '*') -Destination $Destination -Recurse -Force -ErrorAction Stop
      return
    } catch {
      if ($attempts -ge 5) { throw }
      Write-Log ("Copia falló (intento $attempts): " + $_.Exception.Message)
      Start-Sleep -Milliseconds 800
    }
  }
}

function Download-FileWithProgress {
  param(
    [string]$Uri,
    [string]$Destination,
    [long]$TotalBytes,
    [string]$Activity = 'Descargando paquete'
  )

  $request = [System.Net.HttpWebRequest]::Create($Uri)
  $request.UserAgent = 'Nexus-Installer'
  $request.AllowAutoRedirect = $true
  $request.Timeout = 300000

  $response = $request.GetResponse()
  $stream = $response.GetResponseStream()

  if ($TotalBytes -le 0) {
    $TotalBytes = [long]$response.ContentLength
  }

  $fileStream = [System.IO.File]::Create($Destination)
  $buffer = New-Object byte[] 81920
  $totalRead = 0L
  $lastPct = -1

  try {
    while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
      $fileStream.Write($buffer, 0, $read)
      $totalRead += $read

      if ($TotalBytes -gt 0) {
        $pct = [int][math]::Min(100, [math]::Floor(100.0 * $totalRead / $TotalBytes))
        if ($pct -ne $lastPct) {
          $lastPct = $pct
          $status = '{0} / {1} ({2}%)' -f (
            (Format-Megabytes $totalRead),
            (Format-Megabytes $TotalBytes),
            $pct
          )
          Write-Progress -Activity $Activity -Status $status -PercentComplete $pct
        }
      } else {
        $status = '{0} descargados' -f (Format-Megabytes $totalRead)
        Write-Progress -Activity $Activity -Status $status -PercentComplete 0
      }
    }
  } finally {
    $fileStream.Close()
    $stream.Close()
    $response.Close()
    Write-Progress -Activity $Activity -Completed -ErrorAction SilentlyContinue
  }

  return $totalRead
}

function Expand-NexusPackage {
  param(
    [string]$ZipPath,
    [string]$Destination,
    [string]$Activity = 'Extrayendo archivos'
  )

  $staging = Join-Path $env:TEMP ('nexus-install-staging-' + [guid]::NewGuid().ToString())
  New-Item -ItemType Directory -Path $staging -Force | Out-Null
  try {
    Write-Progress -Activity $Activity -Status 'Descomprimiendo paquete...' -PercentComplete 10
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $staging -Force

    $source = $staging
    $entries = @(Get-ChildItem -LiteralPath $staging)
    if ($entries.Count -eq 1 -and $entries[0].PSIsContainer) {
      $source = $entries[0].FullName
      Write-Log ('Raíz del paquete: ' + $source)
    }

    if (-not (Test-Path -LiteralPath (Join-Path $source $ExeName))) {
      throw "El paquete no contiene $ExeName."
    }

    Write-Progress -Activity $Activity -Status 'Copiando archivos a la carpeta de instalación...' -PercentComplete 60
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Copy-Payload -Source $source -Destination $Destination
    Write-Progress -Activity $Activity -Status 'Extracción completada' -PercentComplete 100
  } finally {
    Write-Progress -Activity $Activity -Completed -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function New-Shortcut {
  param(
    [string]$ShortcutPath,
    [string]$TargetPath,
    [string]$WorkingDirectory,
    [string]$Description
  )
  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut($ShortcutPath)
  $shortcut.TargetPath = $TargetPath
  $shortcut.WorkingDirectory = $WorkingDirectory
  $shortcut.Description = $Description
  $shortcut.Save()
}

function Register-UninstallEntry {
  param(
    [string]$Version,
    [string]$InstallLocation
  )

  $uninstallScript = Join-Path $InstallLocation 'uninstall-nexus.ps1'
  if (-not (Test-Path -LiteralPath $uninstallScript)) {
    $uninstallScript = Join-Path $PSScriptRoot 'uninstall-nexus.ps1'
  }

  $psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $uninstallCmd = "`"$psExe`" -NoProfile -ExecutionPolicy Bypass -File `"$uninstallScript`" -InstallDir `"$InstallLocation`""

  New-Item -Path $UninstallKey -Force | Out-Null
  Set-ItemProperty -Path $UninstallKey -Name 'DisplayName' -Value $AppDisplayName
  Set-ItemProperty -Path $UninstallKey -Name 'DisplayVersion' -Value $Version
  Set-ItemProperty -Path $UninstallKey -Name 'Publisher' -Value 'Transworld'
  Set-ItemProperty -Path $UninstallKey -Name 'InstallLocation' -Value $InstallLocation
  Set-ItemProperty -Path $UninstallKey -Name 'UninstallString' -Value $uninstallCmd
  Set-ItemProperty -Path $UninstallKey -Name 'DisplayIcon' -Value (Join-Path $InstallLocation $ExeName)
  Set-ItemProperty -Path $UninstallKey -Name 'NoModify' -Value 1 -Type DWord
  Set-ItemProperty -Path $UninstallKey -Name 'NoRepair' -Value 1 -Type DWord
}

function Install-UninstallScript {
  param([string]$Destination)
  $source = Join-Path $PSScriptRoot 'uninstall-nexus.ps1'
  if (Test-Path -LiteralPath $source) {
    Copy-Item -LiteralPath $source -Destination (Join-Path $Destination 'uninstall-nexus.ps1') -Force
  }
}

function Write-InstalledVersionFile {
  param(
    [string]$Version,
    [string]$InstallLocation
  )
  $versionFile = Join-Path $InstallLocation '.nexus-version'
  Set-Content -LiteralPath $versionFile -Value $Version.Trim() -Encoding ASCII -NoNewline
  Write-Log ('Version persistida en ' + $versionFile)
}

function Stop-NexusIfRunning {
  $proc = Get-Process -Name 'transworld_nexus' -ErrorAction SilentlyContinue
  if (-not $proc) { return }
  Write-Log ('Cerrando Nexus (PID ' + $proc.Id + ') antes de limpiar legacy...')
  $proc | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2
}

function Remove-LegacyInstallArtifacts {
  param([string]$CurrentInstallDir)

  $legacyInstallDir = Join-Path $env:LOCALAPPDATA 'Transworld NEXUS'
  if ($legacyInstallDir -eq $CurrentInstallDir) { return }

  Stop-NexusIfRunning

  $legacyStartMenuDir = Join-Path ([Environment]::GetFolderPath('Programs')) 'Transworld NEXUS'
  $legacyUninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{E68BC201-9F31-48C7-9943-41A6673413E0}_is1'
  $desktop = [Environment]::GetFolderPath('Desktop')

  foreach ($name in @('Transworld NEXUS.lnk')) {
    $shortcut = Join-Path $desktop $name
    if (Test-Path -LiteralPath $shortcut) {
      Remove-Item -LiteralPath $shortcut -Force
      Write-Log ('Acceso directo legacy eliminado: ' + $shortcut)
    }
  }

  foreach ($name in @('Transworld NEXUS.lnk', "$AppDisplayName.lnk")) {
    $shortcut = Join-Path $legacyStartMenuDir $name
    if (Test-Path -LiteralPath $shortcut) {
      Remove-Item -LiteralPath $shortcut -Force
      Write-Log ('Acceso directo legacy eliminado: ' + $shortcut)
    }
  }

  if (Test-Path -LiteralPath $legacyStartMenuDir) {
    Remove-Item -LiteralPath $legacyStartMenuDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log ('Carpeta de menú Inicio legacy eliminada: ' + $legacyStartMenuDir)
  }

  if (Test-Path -LiteralPath $legacyInstallDir) {
    Write-Log ('Eliminando instalación legacy: ' + $legacyInstallDir)
    Remove-Item -LiteralPath $legacyInstallDir -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $legacyInstallDir) {
      Write-Log ('Aviso: no se pudo eliminar por completo ' + $legacyInstallDir)
    }
  }

  if (Test-Path -LiteralPath $legacyUninstallKey) {
    Remove-Item -LiteralPath $legacyUninstallKey -Recurse -Force
    Write-Log 'Entrada de desinstalación legacy (Inno) eliminada.'
  }
}

# --- Main ---

Write-Log '--- Inicio de instalación bootstrap ---'
Show-InstallBanner

try {
  Write-UiStep -Message 'Comprobando permisos de escritura'
  if (-not (Test-DirectoryWritable $InstallDir)) {
    throw "No se puede escribir en la carpeta de instalación: $InstallDir"
  }
  Write-UiOk -Message 'Carpeta de destino accesible'

  Write-UiStep -Message 'Consultando la última versión en GitHub Releases'
  Write-UiWait -Message 'Conectando con GitHub...'

  $headers = @{
    Accept = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent' = 'Nexus-Installer'
  }

  $apiUrl = "https://api.github.com/repos/$Owner/$Repo/releases/latest"
  Write-Log "GET $apiUrl"

  try {
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get
  } catch {
    $status = $null
    if ($_.Exception.Response) {
      $status = [int]$_.Exception.Response.StatusCode
    }
    if ($status -eq 404) {
      throw 'No hay Releases publicados en el repositorio de GitHub.'
    }
    if ($status -eq 403 -or $status -eq 429) {
      throw 'Límite de la API de GitHub alcanzado. Reintenta más tarde.'
    }
    throw "No se pudo consultar GitHub Releases: $($_.Exception.Message)"
  }

  $version = Get-StrippedTag $release.tag_name
  $asset = Resolve-NexusWindowsZipAsset -Release $release
  if ($null -eq $asset) {
    throw "El release $($release.tag_name) no incluye un ZIP de Windows (windows-NEXUS-v*.zip)."
  }

  $assetSizeBytes = [long]$asset.size
  Write-UiOk -Message ('Version v{0} encontrada' -f $version)
  Write-UiDetail -Label 'Paquete' -Value $asset.name
  Write-UiDetail -Label 'Tamaño' -Value (Format-Megabytes $assetSizeBytes)
  Write-Host ''

  Write-UiStep -Message 'Descargando paquete'
  Write-Log ("Release=" + $release.tag_name + ' Asset=' + $asset.name + ' Size=' + (Format-Megabytes $assetSizeBytes))

  $zipPath = Join-Path $env:TEMP ("nexus-install-v$version.zip")
  if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
  }

  $downloadedBytes = Download-FileWithProgress `
    -Uri $asset.browser_download_url `
    -Destination $zipPath `
    -TotalBytes $assetSizeBytes `
    -Activity 'Descargando Nexus'

  Write-UiOk -Message ('Descarga completa: {0}' -f (Format-Megabytes $downloadedBytes))
  Write-Log ('Descarga completada: ' + $zipPath)

  Write-UiStep -Message 'Verificando integridad del paquete'
  if (-not $SkipSha256) {
    $expected = Get-ExpectedSha256Hex $asset.digest
    if ($null -ne $expected) {
      Write-UiWait -Message 'Calculando SHA-256...'
      Start-UiProgress -Activity 'Verificando integridad' -Status 'Calculando SHA-256...' -Percent 50
      $actual = Get-FileSha256Hex -Path $zipPath
      Stop-UiProgress -Activity 'Verificando integridad'
      if ($actual -ne $expected) {
        Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
        throw 'La verificación SHA-256 del paquete descargado falló. Descarga abortada.'
      }
      Write-UiOk -Message 'Integridad verificada'
      Write-Log 'SHA-256 verificado correctamente.'
    } else {
      Write-UiOk -Message 'Verificación omitida (GitHub no publicó digest)'
      Write-Log 'Aviso: el asset no incluye digest SHA-256; se omite verificación.'
    }
  } else {
    Write-UiOk -Message 'Verificación SHA-256 omitida (modo depuración)'
  }

  Write-UiStep -Message 'Extrayendo e instalando archivos'
  Expand-NexusPackage -ZipPath $zipPath -Destination $InstallDir -Activity 'Instalando Nexus'
  Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
  Write-UiOk -Message ('Archivos instalados en {0}' -f $InstallDir)

  Remove-LegacyInstallArtifacts -CurrentInstallDir $InstallDir

  Write-UiStep -Message 'Configurando accesos directos y registro'
  Install-UninstallScript -Destination $InstallDir

  $startMenuRoot = [Environment]::GetFolderPath('Programs')
  $startMenuDir = Join-Path $startMenuRoot 'Nexus'
  New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null

  $exePath = Join-Path $InstallDir $ExeName
  New-Shortcut `
    -ShortcutPath (Join-Path $startMenuDir "$AppDisplayName.lnk") `
    -TargetPath $exePath `
    -WorkingDirectory $InstallDir `
    -Description $AppDisplayName

  if ($DesktopShortcut) {
    $desktop = [Environment]::GetFolderPath('Desktop')
    New-Shortcut `
      -ShortcutPath (Join-Path $desktop "$AppDisplayName.lnk") `
      -TargetPath $exePath `
      -WorkingDirectory $InstallDir `
      -Description $AppDisplayName
    Write-UiOk -Message 'Acceso directo en el escritorio creado'
    Write-Log 'Acceso directo de escritorio creado.'
  }

  Write-UiOk -Message 'Acceso directo en el menú Inicio creado'

  if ($SkipUninstallRegistry) {
    Write-UiOk -Message ('Version v{0} registrada para el instalador' -f $version)
  } else {
    Register-UninstallEntry -Version $version -InstallLocation $InstallDir
    Write-Log 'Entrada de desinstalación registrada.'
    Write-UiOk -Message ('Registro de desinstalación actualizado (v{0})' -f $version)
  }
  Write-InstalledVersionFile -Version $version -InstallLocation $InstallDir

  Write-Host ''
  Write-Host '  ===============================================' -ForegroundColor Green
  Write-Host ('     NEXUS v{0} instalado correctamente' -f $version) -ForegroundColor Green
  Write-Host '  ===============================================' -ForegroundColor Green
  Write-Host ''
  Write-Log 'Instalación completada.'

  if ($Launch) {
    Write-UiWait -Message 'Iniciando Nexus...'
    Start-Process -FilePath $exePath -WorkingDirectory $InstallDir
    Write-Log 'Nexus iniciado.'
  }

  Write-Log '--- Fin de instalación bootstrap ---'
  exit 0
} catch {
  Stop-UiProgress
  Write-UserError $_.Exception.Message
  Write-Host ''
  Write-Host ('  Log: {0}' -f $LogPath) -ForegroundColor DarkGray
  Write-Host ''
  Write-Log '--- Fin con error ---'
  exit 1
}
