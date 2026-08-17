#Requires -Version 5.1
<#
.SYNOPSIS
  Instalador bootstrap de RegisPro para Windows.

.DESCRIPTION
  Consulta la última GitHub Release, descarga windows-regispro-vX.Y.Z.zip,
  extrae en %LOCALAPPDATA%\RegisPro y crea accesos directos.
  No requiere recompilarse por versión: siempre instala el último release.

.PARAMETER Owner
  Owner del repositorio GitHub (default: bastiansanchez24).

.PARAMETER Repo
  Nombre del repositorio GitHub (default: transworld-nexus).

.PARAMETER InstallDir
  Carpeta de destino. Por defecto %LOCALAPPDATA%\RegisPro
  (escribible sin admin, compatible con actualizaciones OTA).

.PARAMETER DesktopShortcut
  Crea un acceso directo en el escritorio.

.PARAMETER Launch
  Abre RegisPro al finalizar la instalación.

.PARAMETER SkipSha256
  Omite la verificación SHA-256 del asset (solo depuración).

.PARAMETER SkipUninstallRegistry
  No registra la entrada de desinstalación (p. ej. cuando Inno Setup ya lo gestiona).
#>
[CmdletBinding()]
param(
  [string]$Owner = 'bastiansanchez24',
  [string]$Repo = 'transworld-nexus',
  [string]$InstallDir = '',
  [switch]$DesktopShortcut,
  [switch]$Launch = $true,
  [switch]$SkipSha256,
  [switch]$SkipUninstallRegistry
)

$ErrorActionPreference = 'Stop'

$ExeName = 'transworld_nexus.exe'
$AppDisplayName = 'RegisPro'
$UninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{E68BC201-9F31-48C7-9943-41A6673413E0}'
$LogPath = Join-Path $env:TEMP 'regispro-install.log'
$UiTotalSteps = 6
$Script:UiStep = 0
$Script:UiProgressOpen = $false
$Script:UiWidth = 58

if ([string]::IsNullOrWhiteSpace($InstallDir)) {
  $InstallDir = Join-Path $env:LOCALAPPDATA 'RegisPro'
}

function Initialize-ConsoleUi {
  try {
    # Consola UTF-8 para tipografía y marco del instalador (también vía Inno).
    $utf8 = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = $utf8
    [Console]::InputEncoding = $utf8
    $OutputEncoding = $utf8
    try {
      $setCp = Add-Type -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern bool SetConsoleOutputCP(uint wCodePageID);
[DllImport("kernel32.dll")] public static extern bool SetConsoleCP(uint wCodePageID);
'@ -Name 'RegisProConsoleCp' -Namespace 'RegisProNative' -PassThru -ErrorAction Stop
      [void]$setCp::SetConsoleOutputCP(65001)
      [void]$setCp::SetConsoleCP(65001)
    } catch { }
  } catch { }

  try {
    $Host.UI.RawUI.WindowTitle = 'RegisPro  ·  Instalador'
  } catch { }

  try {
    $buffer = $Host.UI.RawUI.BufferSize
    if ($buffer.Width -lt 72) {
      $Host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(88, $buffer.Height)
    }
  } catch { }
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

function Write-UiRule {
  param([string]$Char = '─')
  Write-Host ('  ' + ($Char * $Script:UiWidth)) -ForegroundColor DarkCyan
}

function Write-UiBoxLine {
  param(
    [string]$Text = '',
    [ConsoleColor]$Color = [ConsoleColor]::Cyan,
    [switch]$Center
  )
  $inner = $Script:UiWidth - 2
  if ($null -eq $Text) { $Text = '' }
  if ($Text.Length -gt $inner) {
    $Text = $Text.Substring(0, [math]::Max(0, $inner - 1)) + '…'
  }
  if ($Center) {
    $pad = [math]::Max(0, $inner - $Text.Length)
    $left = [math]::Floor($pad / 2)
    $right = $pad - $left
    $content = (' ' * $left) + $Text + (' ' * $right)
  } else {
    $content = $Text.PadRight($inner)
  }
  Write-Host '  ║' -NoNewline -ForegroundColor DarkCyan
  Write-Host $content -NoNewline -ForegroundColor $Color
  Write-Host '║' -ForegroundColor DarkCyan
}

function Show-InstallBanner {
  Clear-Host
  Write-Host ''
  Write-Host ('  ╔' + ('═' * ($Script:UiWidth - 2)) + '╗') -ForegroundColor DarkCyan
  Write-UiBoxLine -Color DarkCyan
  Write-UiBoxLine -Text 'N E X U S' -Color Cyan -Center
  Write-UiBoxLine -Color DarkCyan
  Write-Host ('  ╚' + ('═' * ($Script:UiWidth - 2)) + '╝') -ForegroundColor DarkCyan
  Write-Host ''
  Write-UiDetail -Label 'Destino' -Value $InstallDir
  Write-UiDetail -Label 'Registro' -Value "$Owner/$Repo"
  Write-Host ''
  Write-UiRule
  Write-Host ''
}

function Write-UiStep {
  param([string]$Message)
  $Script:UiStep++
  if ($Script:UiProgressOpen) {
    Write-Host ''
    $Script:UiProgressOpen = $false
  }
  Write-Host ''
  Write-Host '  ' -NoNewline
  Write-Host (' {0}/{1} ' -f $Script:UiStep, $UiTotalSteps) -NoNewline -ForegroundColor Black -BackgroundColor Cyan
  Write-Host ('  {0}' -f $Message) -ForegroundColor White
}

function Write-UiDetail {
  param(
    [string]$Label,
    [string]$Value
  )
  Write-Host '      ' -NoNewline
  Write-Host ('{0,-10}' -f $Label) -NoNewline -ForegroundColor DarkGray
  Write-Host '  ' -NoNewline
  Write-Host $Value -ForegroundColor Gray
}

function Write-UiOk {
  param([string]$Message)
  if ($Script:UiProgressOpen) {
    Write-Host ''
    $Script:UiProgressOpen = $false
  }
  Write-Host '      ' -NoNewline
  Write-Host '✓' -NoNewline -ForegroundColor Green
  Write-Host ('  {0}' -f $Message) -ForegroundColor Green
}

function Write-UiWait {
  param([string]$Message)
  Write-Host '      ' -NoNewline
  Write-Host '…' -NoNewline -ForegroundColor DarkCyan
  Write-Host ('  {0}' -f $Message) -ForegroundColor DarkGray
}

function Write-UiProgressLine {
  param(
    [int]$Percent,
    [string]$Status,
    [int]$BarWidth = 28
  )
  if ($Percent -lt 0) { $Percent = 0 }
  if ($Percent -gt 100) { $Percent = 100 }
  $filled = [int][math]::Round(($BarWidth * $Percent) / 100.0)
  if ($filled -gt $BarWidth) { $filled = $BarWidth }
  $empty = $BarWidth - $filled
  $bar = ('█' * $filled) + ('░' * $empty)
  $line = '      [{0}] {1,3}%  {2}' -f $bar, $Percent, $Status
  if ($line.Length -gt 90) {
    $line = $line.Substring(0, 89) + '…'
  }
  Write-Host ("`r" + $line.PadRight(96)) -NoNewline -ForegroundColor Cyan
  $Script:UiProgressOpen = $true
}

function Close-UiProgressLine {
  if ($Script:UiProgressOpen) {
    Write-Host ''
    $Script:UiProgressOpen = $false
  }
}

function Show-InstallSuccess {
  param([string]$Version)
  Close-UiProgressLine
  Write-Host ''
  Write-UiRule
  Write-Host ''
  Write-Host ('  ╔' + ('═' * ($Script:UiWidth - 2)) + '╗') -ForegroundColor DarkGreen
  Write-Host '  ║' -NoNewline -ForegroundColor DarkGreen
  Write-Host (''.PadRight($Script:UiWidth - 2)) -NoNewline
  Write-Host '║' -ForegroundColor DarkGreen
  Write-Host '  ║' -NoNewline -ForegroundColor DarkGreen
  $title = 'Instalación completada'
  $pad = [math]::Max(0, ($Script:UiWidth - 2) - $title.Length)
  $left = [math]::Floor($pad / 2)
  Write-Host ((' ' * $left) + $title + (' ' * ($pad - $left))) -NoNewline -ForegroundColor Green
  Write-Host '║' -ForegroundColor DarkGreen
  Write-Host '  ║' -NoNewline -ForegroundColor DarkGreen
  $sub = "RegisPro v$Version listo para usar"
  $pad2 = [math]::Max(0, ($Script:UiWidth - 2) - $sub.Length)
  $left2 = [math]::Floor($pad2 / 2)
  Write-Host ((' ' * $left2) + $sub + (' ' * ($pad2 - $left2))) -NoNewline -ForegroundColor Gray
  Write-Host '║' -ForegroundColor DarkGreen
  Write-Host '  ║' -NoNewline -ForegroundColor DarkGreen
  Write-Host (''.PadRight($Script:UiWidth - 2)) -NoNewline
  Write-Host '║' -ForegroundColor DarkGreen
  Write-Host ('  ╚' + ('═' * ($Script:UiWidth - 2)) + '╝') -ForegroundColor DarkGreen
  Write-Host ''
}

function Write-UserError {
  param([string]$Message)
  Write-Progress -Activity 'Instalando RegisPro' -Completed -ErrorAction SilentlyContinue
  Close-UiProgressLine
  Write-Log "ERROR: $Message"
  Write-Host ''
  Write-Host ('  ╔' + ('═' * ($Script:UiWidth - 2)) + '╗') -ForegroundColor DarkRed
  Write-Host '  ║' -NoNewline -ForegroundColor DarkRed
  Write-Host ('  No se pudo completar la instalación'.PadRight($Script:UiWidth - 2)) -NoNewline -ForegroundColor Red
  Write-Host '║' -ForegroundColor DarkRed
  Write-Host ('  ╚' + ('═' * ($Script:UiWidth - 2)) + '╝') -ForegroundColor DarkRed
  Write-Host ''
  Write-Host '      ' -NoNewline
  Write-Host '✗' -NoNewline -ForegroundColor Red
  Write-Host ('  {0}' -f $Message) -ForegroundColor Red
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
  param([string]$Activity = 'Instalando RegisPro')
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
  $exactRegisPro = "windows-regispro-v$tag.zip"
  $exactLegacy = "windows-nexus-v$tag.zip"

  # Prefiere windows-regispro-*.zip; acepta windows-nexus-*.zip (legacy).
  $candidates = @(
    $Release.assets | Where-Object {
      $_.name -match '(?i)^windows-(regispro|nexus)-.+\.zip$'
    }
  )
  if ($candidates.Count -eq 0) { return $null }

  foreach ($c in $candidates) {
    if ($c.name.ToLowerInvariant() -eq $exactRegisPro) { return $c }
  }
  foreach ($c in $candidates) {
    if ($c.name.ToLowerInvariant() -eq $exactLegacy) { return $c }
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
  $probe = Join-Path $DirPath (".regispro-write-probe-" + [guid]::NewGuid().ToString())
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
  $request.UserAgent = 'RegisPro-Installer'
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
  $lastDraw = [datetime]::MinValue

  try {
    while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
      $fileStream.Write($buffer, 0, $read)
      $totalRead += $read

      $now = Get-Date
      $shouldDraw = ($now - $lastDraw).TotalMilliseconds -ge 120

      if ($TotalBytes -gt 0) {
        $pct = [int][math]::Min(100, [math]::Floor(100.0 * $totalRead / $TotalBytes))
        if (($pct -ne $lastPct -and $shouldDraw) -or $pct -eq 100) {
          $lastPct = $pct
          $lastDraw = $now
          $status = '{0} / {1}' -f (
            (Format-Megabytes $totalRead),
            (Format-Megabytes $TotalBytes)
          )
          Write-UiProgressLine -Percent $pct -Status $status
          Write-Progress -Activity $Activity -Status $status -PercentComplete $pct
        }
      } elseif ($shouldDraw) {
        $lastDraw = $now
        $status = '{0} descargados' -f (Format-Megabytes $totalRead)
        Write-UiProgressLine -Percent 0 -Status $status
        Write-Progress -Activity $Activity -Status $status -PercentComplete 0
      }
    }
  } finally {
    $fileStream.Close()
    $stream.Close()
    $response.Close()
    Write-Progress -Activity $Activity -Completed -ErrorAction SilentlyContinue
    Close-UiProgressLine
  }

  return $totalRead
}

function Expand-NexusPackage {
  param(
    [string]$ZipPath,
    [string]$Destination,
    [string]$Activity = 'Extrayendo archivos'
  )

  $staging = Join-Path $env:TEMP ('regispro-install-staging-' + [guid]::NewGuid().ToString())
  New-Item -ItemType Directory -Path $staging -Force | Out-Null
  try {
    Write-UiProgressLine -Percent 10 -Status 'Descomprimiendo paquete...'
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

    Write-UiProgressLine -Percent 60 -Status 'Copiando archivos...'
    Write-Progress -Activity $Activity -Status 'Copiando archivos a la carpeta de instalación...' -PercentComplete 60
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Copy-Payload -Source $source -Destination $Destination
    Write-UiProgressLine -Percent 100 -Status 'Extracción completada'
    Write-Progress -Activity $Activity -Status 'Extracción completada' -PercentComplete 100
  } finally {
    Write-Progress -Activity $Activity -Completed -ErrorAction SilentlyContinue
    Close-UiProgressLine
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

  $uninstallScript = Join-Path $InstallLocation 'uninstall-regispro.ps1'
  if (-not (Test-Path -LiteralPath $uninstallScript)) {
    $uninstallScript = Join-Path $PSScriptRoot 'uninstall-regispro.ps1'
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
  $source = Join-Path $PSScriptRoot 'uninstall-regispro.ps1'
  if (Test-Path -LiteralPath $source) {
    Copy-Item -LiteralPath $source -Destination (Join-Path $Destination 'uninstall-regispro.ps1') -Force
  }
}

function Write-InstalledVersionFile {
  param(
    [string]$Version,
    [string]$InstallLocation
  )
  $versionFile = Join-Path $InstallLocation '.regispro-version'
  Set-Content -LiteralPath $versionFile -Value $Version.Trim() -Encoding ASCII -NoNewline
  Write-Log ('Version persistida en ' + $versionFile)
}

function Stop-RegisProIfRunning {
  $proc = Get-Process -Name 'transworld_nexus' -ErrorAction SilentlyContinue
  if (-not $proc) { return }
  Write-Log ('Cerrando RegisPro (PID ' + $proc.Id + ') antes de limpiar legacy...')
  $proc | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2
}

function Remove-LegacyInstallArtifacts {
  param([string]$CurrentInstallDir)

  Stop-RegisProIfRunning

  $legacyDirs = @(
    (Join-Path $env:LOCALAPPDATA 'Nexus'),
    (Join-Path $env:LOCALAPPDATA 'Transworld NEXUS')
  )
  foreach ($legacyInstallDir in $legacyDirs) {
    if ($legacyInstallDir -eq $CurrentInstallDir) { continue }
    if (Test-Path -LiteralPath $legacyInstallDir) {
      Remove-Item -LiteralPath $legacyInstallDir -Recurse -Force -ErrorAction SilentlyContinue
      Write-Log ('Instalación legacy eliminada: ' + $legacyInstallDir)
    }
  }

  $legacyStartMenuDirs = @(
    (Join-Path ([Environment]::GetFolderPath('Programs')) 'Transworld NEXUS'),
    (Join-Path ([Environment]::GetFolderPath('Programs')) 'Nexus')
  )
  foreach ($legacyStartMenuDir in $legacyStartMenuDirs) {
    if (($legacyStartMenuDir -ne (Join-Path ([Environment]::GetFolderPath('Programs')) $AppDisplayName)) -and
        (Test-Path -LiteralPath $legacyStartMenuDir)) {
      Remove-Item -LiteralPath $legacyStartMenuDir -Recurse -Force -ErrorAction SilentlyContinue
      Write-Log ('Carpeta de menú Inicio legacy eliminada: ' + $legacyStartMenuDir)
    }
  }

  $legacyUninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{E68BC201-9F31-48C7-9943-41A6673413E0}_is1'
  if (Test-Path -LiteralPath $legacyUninstallKey) {
    Remove-Item -LiteralPath $legacyUninstallKey -Recurse -Force -ErrorAction SilentlyContinue
  }

  $desktop = [Environment]::GetFolderPath('Desktop')
  foreach ($name in @('Transworld NEXUS.lnk', 'Nexus.lnk')) {
    $shortcut = Join-Path $desktop $name
    if (Test-Path -LiteralPath $shortcut) {
      Remove-Item -LiteralPath $shortcut -Force -ErrorAction SilentlyContinue
      Write-Log ('Acceso directo legacy eliminado: ' + $shortcut)
    }
  }

  # También limpia accesos antiguos en el menú Inicio de la app actual si quedaron.
  $currentStartMenu = Join-Path ([Environment]::GetFolderPath('Programs')) $AppDisplayName
  foreach ($name in @('Transworld NEXUS.lnk', 'Nexus.lnk')) {
    $shortcut = Join-Path $currentStartMenu $name
    if (Test-Path -LiteralPath $shortcut) {
      Remove-Item -LiteralPath $shortcut -Force -ErrorAction SilentlyContinue
    }
  }
}

# --- Main ---

Initialize-ConsoleUi
Write-Log '--- Inicio de instalación bootstrap ---'
Show-InstallBanner

try {
  Write-UiStep -Message 'Comprobando permisos de escritura'
  if (-not (Test-DirectoryWritable $InstallDir)) {
    throw "No se puede escribir en la carpeta de instalación: $InstallDir"
  }
  Write-UiOk -Message 'Carpeta de destino accesible'

  Write-UiStep -Message 'Consultando la última versión'
  Write-UiWait -Message 'Conectando con GitHub Releases...'

  $headers = @{
    Accept = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent' = 'RegisPro-Installer'
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
    throw "El release $($release.tag_name) no incluye un ZIP de Windows (windows-regispro-v*.zip)."
  }

  $assetSizeBytes = [long]$asset.size
  Write-UiOk -Message ('Versión v{0} encontrada' -f $version)
  Write-UiDetail -Label 'Paquete' -Value $asset.name
  Write-UiDetail -Label 'Tamaño' -Value (Format-Megabytes $assetSizeBytes)

  Write-UiStep -Message 'Descargando paquete'
  Write-Log ("Release=" + $release.tag_name + ' Asset=' + $asset.name + ' Size=' + (Format-Megabytes $assetSizeBytes))

  $zipPath = Join-Path $env:TEMP ("regispro-install-v$version.zip")
  if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
  }

  $downloadedBytes = Download-FileWithProgress `
    -Uri $asset.browser_download_url `
    -Destination $zipPath `
    -TotalBytes $assetSizeBytes `
    -Activity 'Descargando RegisPro'

  Write-UiOk -Message ('Descarga completa · {0}' -f (Format-Megabytes $downloadedBytes))
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
      Write-UiOk -Message 'Integridad verificada (SHA-256)'
      Write-Log 'SHA-256 verificado correctamente.'
    } else {
      Write-UiOk -Message 'Verificación omitida (GitHub no publicó digest)'
      Write-Log 'Aviso: el asset no incluye digest SHA-256; se omite verificación.'
    }
  } else {
    Write-UiOk -Message 'Verificación SHA-256 omitida (modo depuración)'
  }

  Write-UiStep -Message 'Extrayendo e instalando archivos'
  Expand-NexusPackage -ZipPath $zipPath -Destination $InstallDir -Activity 'Instalando RegisPro'
  Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
  Write-UiOk -Message ('Archivos instalados en {0}' -f $InstallDir)

  Remove-LegacyInstallArtifacts -CurrentInstallDir $InstallDir

  Write-UiStep -Message 'Configurando accesos directos y registro'
  Install-UninstallScript -Destination $InstallDir

  $startMenuRoot = [Environment]::GetFolderPath('Programs')
  $startMenuDir = Join-Path $startMenuRoot $AppDisplayName
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
    Write-UiOk -Message ('Versión v{0} registrada para el instalador' -f $version)
  } else {
    Register-UninstallEntry -Version $version -InstallLocation $InstallDir
    Write-Log 'Entrada de desinstalación registrada.'
    Write-UiOk -Message ('Registro de desinstalación actualizado (v{0})' -f $version)
  }
  Write-InstalledVersionFile -Version $version -InstallLocation $InstallDir

  Show-InstallSuccess -Version $version
  Write-Log 'Instalación completada.'

  if ($Launch) {
    Write-UiWait -Message 'Iniciando RegisPro...'
    Start-Process -FilePath $exePath -WorkingDirectory $InstallDir
    Write-Log 'RegisPro iniciado.'
  }

  Write-Log '--- Fin de instalación bootstrap ---'
  exit 0
} catch {
  Stop-UiProgress
  Write-UserError $_.Exception.Message
  Write-Host ''
  Write-Host '      ' -NoNewline
  Write-Host 'Log' -NoNewline -ForegroundColor DarkGray
  Write-Host ('  {0}' -f $LogPath) -ForegroundColor DarkGray
  Write-Host ''
  Write-Log '--- Fin con error ---'
  exit 1
}
