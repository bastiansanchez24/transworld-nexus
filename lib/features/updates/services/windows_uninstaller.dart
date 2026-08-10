import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Resultado de intentar lanzar la desinstalación en Windows.
enum WindowsUninstallOutcome {
  launched,
  unsupportedPlatform,
  scriptMissing,
  failed,
}

class WindowsUninstallResult {
  const WindowsUninstallResult(this.outcome, {this.message});

  final WindowsUninstallOutcome outcome;
  final String? message;
}

/// Lanza la desinstalación fuera del Job Object de Flutter (vía `cmd /c start`).
///
/// Escribe un wrapper temporal que espera al cierre de la app y luego ejecuta
/// `uninstall-nexus.ps1` del directorio de instalación (compatible con scripts
/// antiguos que no aceptan `-ParentPid`). La app debe cerrarse tras
/// [WindowsUninstallOutcome.launched].
class WindowsUninstaller {
  Future<WindowsUninstallResult> uninstall() async {
    if (kIsWeb || !Platform.isWindows) {
      return const WindowsUninstallResult(
        WindowsUninstallOutcome.unsupportedPlatform,
        message: 'La desinstalación solo está disponible en Windows.',
      );
    }

    final exePath = Platform.resolvedExecutable;
    final installDir = File(exePath).parent.path;
    final installedScript = '$installDir\\uninstall-nexus.ps1';

    if (!File(installedScript).existsSync()) {
      return WindowsUninstallResult(
        WindowsUninstallOutcome.scriptMissing,
        message:
            'No se encontró el desinstalador en $installDir. '
            'Usa Configuración → Aplicaciones → RegisPro, o vuelve a instalar '
            'con RegisProSetup.',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final wrapperPath = '${tempDir.path}\\nexus-uninstall-$stamp.ps1';
    final launcherPath = '${tempDir.path}\\nexus-uninstall-launch-$stamp.cmd';

    try {
      await File(wrapperPath).writeAsString(
        '\u{FEFF}${_wrapperScript(
          uninstallScript: installedScript,
          installDir: installDir,
          parentPid: pid,
        )}',
        flush: true,
      );
      await File(launcherPath).writeAsString(
        '\u{FEFF}${_launcherCmd(
          powershell: _powershellExecutable,
          scriptPath: wrapperPath,
        )}',
        flush: true,
      );
    } catch (e) {
      return WindowsUninstallResult(
        WindowsUninstallOutcome.failed,
        message: 'No se pudo preparar el desinstalador: $e',
      );
    }

    try {
      await Process.start(
        'cmd.exe',
        ['/d', '/c', launcherPath],
        mode: ProcessStartMode.detached,
        workingDirectory: tempDir.path,
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return const WindowsUninstallResult(WindowsUninstallOutcome.launched);
    } catch (e) {
      return WindowsUninstallResult(
        WindowsUninstallOutcome.failed,
        message: 'No se pudo iniciar el desinstalador: $e',
      );
    }
  }

  static String get _powershellExecutable {
    final systemRoot = Platform.environment['SystemRoot'];
    if (systemRoot == null || systemRoot.isEmpty) return 'powershell.exe';
    final resolved =
        '$systemRoot\\System32\\WindowsPowerShell\\v1.0\\powershell.exe';
    return File(resolved).existsSync() ? resolved : 'powershell.exe';
  }

  /// Espera al PID padre y luego invoca el script instalado sin parámetros
  /// nuevos (así funciona con desinstaladores ya desplegados).
  static String _wrapperScript({
    required String uninstallScript,
    required String installDir,
    required int parentPid,
  }) {
    // Rutas escapadas para literal PowerShell de comillas simples.
    String psLiteral(String value) => value.replaceAll("'", "''");

    return '''
\$ErrorActionPreference = 'Stop'
\$ParentPid = $parentPid
\$UninstallScript = '${psLiteral(uninstallScript)}'
\$InstallDir = '${psLiteral(installDir)}'
\$LogPath = Join-Path \$env:TEMP 'nexus-uninstall.log'

function Write-Log([string]\$Message) {
  \$line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), \$Message
  try { Add-Content -LiteralPath \$LogPath -Value \$line -Encoding UTF8 } catch { }
}

Write-Log '--- Wrapper desinstalacion in-app ---'

if (\$ParentPid -gt 0) {
  try {
    \$parent = Get-Process -Id \$ParentPid -ErrorAction SilentlyContinue
    if (\$parent) {
      Write-Log ('Esperando cierre del proceso ' + \$ParentPid + '...')
      \$null = \$parent.WaitForExit(180000)
    }
  } catch {
    Write-Log ('Aviso esperando el proceso padre: ' + \$_.Exception.Message)
  }
}

\$deadline = (Get-Date).AddSeconds(60)
while ((Get-Date) -lt \$deadline) {
  \$proc = Get-Process -Name 'transworld_nexus' -ErrorAction SilentlyContinue
  if (-not \$proc) { break }
  Start-Sleep -Milliseconds 500
}

Start-Sleep -Milliseconds 800

& \$UninstallScript -InstallDir \$InstallDir
exit \$LASTEXITCODE
''';
  }

  static String _launcherCmd({
    required String powershell,
    required String scriptPath,
  }) {
    String q(String value) => '"${value.replaceAll('"', '')}"';
    final psArgs = [
      '-NoProfile',
      '-WindowStyle',
      'Hidden',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      q(scriptPath),
    ].join(' ');

    return '''
@echo off
chcp 65001 >nul
start "NexusUninstall" /b ${q(powershell)} $psArgs
''';
  }
}
