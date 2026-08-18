@echo off
setlocal
title RegisPro  ·  Instalador
chcp 65001 >nul 2>&1
color 0B

set "SCRIPT_DIR=%~dp0"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

if not exist "%PS%" (
  color 0C
  echo.
  echo   No se encontro PowerShell en este equipo.
  echo.
  pause
  exit /b 1
)

"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install-nexus.ps1" %*
set "ERR=%ERRORLEVEL%"

if not "%ERR%"=="0" (
  echo.
  pause
)

exit /b %ERR%
