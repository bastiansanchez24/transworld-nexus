#Requires -Version 5.1
<#
.SYNOPSIS
  Compila el instalador bootstrap con Inno Setup (ISCC).

.DESCRIPTION
  Requiere Inno Setup 6+ instalado. Busca ISCC.exe en rutas habituales
  o usa la variable de entorno INNO_SETUP_COMPILER.

.EXAMPLE
  .\scripts\build-installer.ps1
#>
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$issPath = Join-Path $repoRoot 'installer_script.iss'
$outDir = Join-Path $repoRoot 'build\windows\installer'

function Find-Iscc {
  if ($env:INNO_SETUP_COMPILER -and (Test-Path -LiteralPath $env:INNO_SETUP_COMPILER)) {
    return $env:INNO_SETUP_COMPILER
  }

  $candidates = @(
    "${env:ProgramFiles}\Inno Setup 7\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 7\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 5\ISCC.exe"
  )

  foreach ($path in $candidates) {
    if (Test-Path -LiteralPath $path) { return $path }
  }

  return $null
}

$iscc = Find-Iscc
if (-not $iscc) {
  throw @'
No se encontró ISCC.exe (Inno Setup).

Instala Inno Setup 6 desde https://jrsoftware.org/isinfo.php
o define INNO_SETUP_COMPILER con la ruta completa a ISCC.exe.
'@
}

New-Item -ItemType Directory -Path $outDir -Force | Out-Null

Write-Host "Compilando instalador bootstrap..." -ForegroundColor Cyan
Write-Host "  ISCC: $iscc"
Write-Host "  Script: $issPath"
Write-Host "  Salida: $outDir"

& $iscc $issPath

$exe = Join-Path $outDir 'NexusSetup.exe'
if (-not (Test-Path -LiteralPath $exe)) {
  throw "No se generó NexusSetup.exe en $outDir"
}

Write-Host ''
Write-Host "Listo: $exe" -ForegroundColor Green
