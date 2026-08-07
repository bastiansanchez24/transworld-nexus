<#
.SYNOPSIS
  Prueba de integración del actualizador OTA de Windows.

.DESCRIPTION
  Extrae los scripts PowerShell embebidos en windows_installer.dart, crea una
  instalación y un ZIP ficticios dentro de %TEMP%, lanza el updater mediante
  el shell de Windows y valida que el binario y .nexus-version hayan sido
  reemplazados.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$dartPath = Join-Path $repoRoot 'lib\features\updates\services\windows_installer.dart'
$testRoot = Join-Path $env:TEMP ('nexus-ota-integration-' + [guid]::NewGuid().ToString())
$installDir = Join-Path $testRoot 'Instalación con espacios'
$payloadDir = Join-Path $testRoot 'payload'
$zipPath = Join-Path $testRoot 'windows-nexus-v9.9.9.zip'
$updaterPath = Join-Path $testRoot 'nexus-update.ps1'
$launcherPath = Join-Path $testRoot 'nexus-update-launch.ps1'
$readyPath = Join-Path $testRoot 'nexus-update-ready'
$exeName = 'nexus-ota-test.exe'

function Get-DartRawString {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Name
  )

  $escapedName = [regex]::Escape($Name)
  $pattern = "const $escapedName = r'''\r?\n([\s\S]*?)\r?\n''';"
  $match = [regex]::Match($Source, $pattern)
  if (-not $match.Success) {
    throw "No se encontró el raw string $Name en $dartPath"
  }
  return $match.Groups[1].Value
}

try {
  New-Item -ItemType Directory -Path $installDir, $payloadDir -Force | Out-Null

  $oldSource = Join-Path $env:SystemRoot 'System32\where.exe'
  $newSource = Join-Path $env:SystemRoot 'System32\whoami.exe'
  Copy-Item -LiteralPath $oldSource -Destination (Join-Path $installDir $exeName)
  Copy-Item -LiteralPath $newSource -Destination (Join-Path $payloadDir $exeName)
  Set-Content -LiteralPath (Join-Path $installDir 'conservar.txt') -Value 'usuario'
  Set-Content -LiteralPath (Join-Path $payloadDir 'nuevo.txt') -Value 'v9.9.9'
  Compress-Archive -Path (Join-Path $payloadDir '*') -DestinationPath $zipPath

  $dartSource = Get-Content -LiteralPath $dartPath -Raw
  $updater = Get-DartRawString -Source $dartSource -Name '_updaterScript'
  $launcher = Get-DartRawString -Source $dartSource -Name '_shellLauncherScript'
  $utf8Bom = New-Object System.Text.UTF8Encoding($true)
  [IO.File]::WriteAllText($updaterPath, $updater, $utf8Bom)
  [IO.File]::WriteAllText($launcherPath, $launcher, $utf8Bom)

  $powershellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $output = & $powershellPath -NoProfile -ExecutionPolicy Bypass -File $launcherPath `
    -PowerShellPath $powershellPath `
    -UpdaterScript $updaterPath `
    -ZipPath $zipPath `
    -InstallDir $installDir `
    -ExeName $exeName `
    -ParentPid 0 `
    -ReadyPath $readyPath `
    -RemoteVersion '9.9.9'

  if ($LASTEXITCODE -ne 0) {
    throw "El launcher WMI terminó con código $LASTEXITCODE"
  }
  $deadline = (Get-Date).AddSeconds(30)
  $versionPath = Join-Path $installDir '.nexus-version'
  while ((Get-Date) -lt $deadline -and -not (Test-Path -LiteralPath $versionPath)) {
    Start-Sleep -Milliseconds 100
  }

  if (-not (Test-Path -LiteralPath $versionPath)) {
    throw 'El updater no escribió .nexus-version dentro del plazo.'
  }
  if ((Get-Content -LiteralPath $versionPath -Raw).Trim() -ne '9.9.9') {
    throw 'La versión instalada no coincide con la versión remota.'
  }
  if (-not (Test-Path -LiteralPath (Join-Path $installDir 'nuevo.txt'))) {
    throw 'El payload nuevo no fue copiado a la instalación.'
  }
  if (-not (Test-Path -LiteralPath (Join-Path $installDir 'conservar.txt'))) {
    throw 'El updater eliminó un archivo local que debía conservarse.'
  }

  $expectedHash = (Get-FileHash -LiteralPath $newSource -Algorithm SHA256).Hash
  $installedHash = (Get-FileHash -LiteralPath (Join-Path $installDir $exeName) -Algorithm SHA256).Hash
  if ($installedHash -ne $expectedHash) {
    throw 'El ejecutable instalado no coincide con el del ZIP.'
  }

  Write-Host 'OK: shell launcher, handshake, extracción y reemplazo verificados.' -ForegroundColor Green
} finally {
  if (Test-Path -LiteralPath $testRoot) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
