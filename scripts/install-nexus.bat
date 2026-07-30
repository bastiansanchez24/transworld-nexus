@echo off
setlocal
title Instalador Nexus

set "SCRIPT_DIR=%~dp0"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

if not exist "%PS%" (
  echo No se encontro PowerShell en este equipo.
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
