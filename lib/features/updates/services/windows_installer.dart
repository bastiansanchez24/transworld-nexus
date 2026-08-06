import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Resultado de intentar aplicar una actualización Windows.
enum WindowsInstallOutcome {
  launched,
  unsupportedPlatform,
  failed,
}

class WindowsInstallResult {
  const WindowsInstallResult(this.outcome, {this.message});

  final WindowsInstallOutcome outcome;
  final String? message;
}

/// Aplica un ZIP descargado: lanza un script PowerShell que espera a que la
/// app libere el `.exe`, extrae el ZIP sobre el directorio de instalación y
/// reinicia Nexus.
///
/// El script se lanza *fuera* del Job Object de Flutter mediante el shell de
/// Windows (Explorer);
/// la app debe cerrarse inmediatamente después de recibir
/// [WindowsInstallOutcome.launched] para liberar los archivos.
class WindowsInstaller {
  /// Lanza el actualizador. Solo devuelve [WindowsInstallOutcome.launched]
  /// cuando el directorio de instalación es escribible, de modo que la app
  /// nunca se cierre para una actualización que no puede aplicarse.
  Future<WindowsInstallResult> install(
    File zipFile, {
    String? remoteVersion,
  }) async {
    if (kIsWeb || !Platform.isWindows) {
      return const WindowsInstallResult(
        WindowsInstallOutcome.unsupportedPlatform,
        message:
            'Las actualizaciones OTA en Windows solo están disponibles en el escritorio.',
      );
    }

    if (!await zipFile.exists()) {
      return const WindowsInstallResult(
        WindowsInstallOutcome.failed,
        message: 'No se encontró el paquete descargado.',
      );
    }

    final exePath = Platform.resolvedExecutable;
    final installDir = File(exePath).parent.path;
    final exeName = _exeFileName(exePath);

    // Pre-flight: si no podemos escribir en el directorio de instalación
    // (típico en `C:\Program Files` sin elevación) abortamos ANTES de cerrar
    // la app; de lo contrario el usuario se queda sin Nexus abierto y sin
    // actualización aplicada.
    if (!await _isDirectoryWritable(installDir)) {
      return WindowsInstallResult(
        WindowsInstallOutcome.failed,
        message:
            'No se puede escribir en la carpeta de instalación ($installDir). '
            'Ejecuta Nexus como administrador o instálalo en una carpeta de usuario.',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final scriptPath = '${tempDir.path}\\nexus-update-$stamp.ps1';
    final launcherPath = '${tempDir.path}\\nexus-update-launch-$stamp.ps1';
    final readyPath = '${tempDir.path}\\nexus-update-ready-$stamp';

    try {
      // BOM obligatorio: Windows PowerShell 5.1 decodifica los archivos sin
      // BOM como ANSI y corrompería los acentos del script.
      await File(scriptPath).writeAsString(
        '\u{FEFF}$_updaterScript',
        flush: true,
      );
      // Shell.Application delega el arranque a Explorer, fuera del Job Object
      // de Flutter. Así el updater sobrevive al `exit(0)` de Nexus sin admin.
      await File(launcherPath).writeAsString(
        '\u{FEFF}$_shellLauncherScript',
        flush: true,
      );
    } catch (e) {
      return WindowsInstallResult(
        WindowsInstallOutcome.failed,
        message: 'No se pudo preparar el actualizador: $e',
      );
    }

    try {
      final launch = await Process.run(
        _powershellExecutable,
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          launcherPath,
          '-PowerShellPath',
          _powershellExecutable,
          '-UpdaterScript',
          scriptPath,
          '-ZipPath',
          zipFile.path,
          '-InstallDir',
          installDir,
          '-ExeName',
          exeName,
          '-ParentPid',
          '$pid',
          '-ReadyPath',
          readyPath,
          if (remoteVersion != null && remoteVersion.isNotEmpty) ...[
            '-RemoteVersion',
            remoteVersion,
          ],
        ],
        workingDirectory: tempDir.path,
      );

      try {
        await File(launcherPath).delete();
      } catch (_) {}

      if (launch.exitCode != 0) {
        return WindowsInstallResult(
          WindowsInstallOutcome.failed,
          message: 'Windows no pudo crear el proceso actualizador: '
              '${launch.stderr.toString().trim()}',
        );
      }

      final ready = File(readyPath);
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (DateTime.now().isBefore(deadline) && !await ready.exists()) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      if (!await ready.exists()) {
        return const WindowsInstallResult(
          WindowsInstallOutcome.failed,
          message: 'El actualizador de Windows no alcanzó a iniciar. '
              'Nexus permanecerá abierto; vuelve a intentarlo.',
        );
      }

      try {
        await ready.delete();
      } catch (_) {}
      return const WindowsInstallResult(WindowsInstallOutcome.launched);
    } catch (e) {
      return WindowsInstallResult(
        WindowsInstallOutcome.failed,
        message: 'No se pudo iniciar el actualizador: $e',
      );
    }
  }

  /// Nombre del .exe sin usar `Uri` (más fiable con rutas Windows).
  static String _exeFileName(String exePath) {
    final normalized = exePath.replaceAll('/', '\\');
    final idx = normalized.lastIndexOf('\\');
    return idx < 0 ? normalized : normalized.substring(idx + 1);
  }

  /// Ruta absoluta de PowerShell (no depende del `PATH` del proceso).
  static String get _powershellExecutable {
    final systemRoot = Platform.environment['SystemRoot'];
    if (systemRoot == null || systemRoot.isEmpty) return 'powershell.exe';
    final resolved =
        '$systemRoot\\System32\\WindowsPowerShell\\v1.0\\powershell.exe';
    return File(resolved).existsSync() ? resolved : 'powershell.exe';
  }

  /// Escribe un archivo sonda para confirmar permisos de escritura reales
  /// (ACL + virtualización), que `FileStat` no refleja de forma fiable.
  static Future<bool> _isDirectoryWritable(String dirPath) async {
    final probe = File(
      '$dirPath\\.nexus-write-probe-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await probe.writeAsString('ok', flush: true);
      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        if (await probe.exists()) await probe.delete();
      } catch (_) {}
    }
  }
}

/// Trampolín que pide al shell de Windows crear el proceso PowerShell.
/// El comando real se codifica en UTF-16LE/Base64 para conservar sin ambigüedad
/// rutas con espacios, acentos y apóstrofes.
const _shellLauncherScript = r'''
param(
  [Parameter(Mandatory = $true)][string]$PowerShellPath,
  [Parameter(Mandatory = $true)][string]$UpdaterScript,
  [Parameter(Mandatory = $true)][string]$ZipPath,
  [Parameter(Mandatory = $true)][string]$InstallDir,
  [Parameter(Mandatory = $true)][string]$ExeName,
  [Parameter(Mandatory = $true)][int]$ParentPid,
  [Parameter(Mandatory = $true)][string]$ReadyPath,
  [string]$RemoteVersion = ''
)

$ErrorActionPreference = 'Stop'

function ConvertTo-SingleQuotedLiteral([string]$Value) {
  return "'" + $Value.Replace("'", "''") + "'"
}

$invocation = @(
  '&',
  (ConvertTo-SingleQuotedLiteral $UpdaterScript),
  '-ZipPath', (ConvertTo-SingleQuotedLiteral $ZipPath),
  '-InstallDir', (ConvertTo-SingleQuotedLiteral $InstallDir),
  '-ExeName', (ConvertTo-SingleQuotedLiteral $ExeName),
  '-ParentPid', $ParentPid,
  '-ReadyPath', (ConvertTo-SingleQuotedLiteral $ReadyPath),
  '-RemoteVersion', (ConvertTo-SingleQuotedLiteral $RemoteVersion)
) -join ' '

$encoded = [Convert]::ToBase64String(
  [Text.Encoding]::Unicode.GetBytes($invocation)
)
$arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand ' + $encoded
$shell = New-Object -ComObject Shell.Application
$shell.ShellExecute($PowerShellPath, $arguments, $InstallDir, 'open', 0)
''';

/// Actualizador out-of-process.
///
/// Garantías de diseño:
/// * Nunca deja al usuario sin app: si algo falla, restaura el backup y
///   relanza el ejecutable original.
/// * Valida que el ZIP contenga realmente el `.exe` antes de sobrescribir.
/// * Deja traza en `%TEMP%\nexus-update.log` para diagnóstico.
const _updaterScript = r'''
param(
  [Parameter(Mandatory = $true)][string]$ZipPath,
  [Parameter(Mandatory = $true)][string]$InstallDir,
  [Parameter(Mandatory = $true)][string]$ExeName,
  [int]$ParentPid = 0,
  [Parameter(Mandatory = $true)][string]$ReadyPath,
  [string]$RemoteVersion = ''
)

$ErrorActionPreference = 'Stop'
$exePath = Join-Path $InstallDir $ExeName
$logPath = Join-Path $env:TEMP 'nexus-update.log'
$staging = Join-Path $env:TEMP ('nexus-update-' + [guid]::NewGuid().ToString())
$backup = Join-Path $staging '__backup'
$payloadGlob = '*'

function Write-Log([string]$Message) {
  $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
  try { Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8 } catch { }
}

function Start-Nexus {
  try {
    if (Test-Path -LiteralPath $exePath) {
      Start-Process -FilePath $exePath -WorkingDirectory $InstallDir
      Write-Log ('Nexus relanzado: ' + $exePath)
    } else {
      Write-Log ('ERROR: no existe el ejecutable para relanzar: ' + $exePath)
    }
  } catch {
    Write-Log ('ERROR al relanzar Nexus: ' + $_.Exception.Message)
  }
}

function Test-FileUnlocked([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $true }
  try {
    $stream = [System.IO.File]::Open($Path, 'Open', 'ReadWrite', 'None')
    $stream.Close()
    $stream.Dispose()
    return $true
  } catch {
    return $false
  }
}

function Test-InstallDirUnlocked {
  $targets = @(
    $exePath,
    (Join-Path $InstallDir 'flutter_windows.dll')
  )
  foreach ($t in $targets) {
    if (-not (Test-FileUnlocked $t)) { return $false }
  }
  return $true
}

# Copia recursiva con reintentos: tolera handles que el SO aún no liberó
# (antivirus, indexador, DLLs recién descargadas).
function Copy-Payload([string]$Source, [string]$Destination) {
  $attempts = 0
  while ($true) {
    $attempts++
    try {
      Copy-Item -Path (Join-Path $Source $payloadGlob) -Destination $Destination -Recurse -Force -ErrorAction Stop
      return
    } catch {
      if ($attempts -ge 8) { throw }
      Write-Log ('Copia falló (intento ' + $attempts + '): ' + $_.Exception.Message)
      Start-Sleep -Milliseconds 1000
    }
  }
}

Write-Log '--- Inicio de actualización ---'
Write-Log ('InstallDir=' + $InstallDir + ' ExeName=' + $ExeName + ' Zip=' + $ZipPath + ' Pid=' + $PID)

# Handshake con Nexus: confirma que PowerShell inició y pudo interpretar todos
# los parámetros antes de que la app se cierre y libere sus binarios.
try {
  Set-Content -LiteralPath $ReadyPath -Value $PID -Encoding ASCII
  Write-Log 'Actualizador listo; esperando cierre de Nexus.'
} catch {
  Write-Log ('ERROR creando señal de inicio: ' + $_.Exception.Message)
  exit 1
}

# 1. Esperar a que la app cierre (por PID y por lock del .exe / DLL).
if ($ParentPid -gt 0) {
  try {
    $parent = Get-Process -Id $ParentPid -ErrorAction SilentlyContinue
    if ($parent) {
      Write-Log ('Esperando cierre del proceso ' + $ParentPid + '...')
      $null = $parent.WaitForExit(180000)
    } else {
      Write-Log ('Proceso padre ' + $ParentPid + ' ya no existe.')
    }
  } catch {
    Write-Log ('Aviso esperando el proceso padre: ' + $_.Exception.Message)
  }
}

$deadline = (Get-Date).AddSeconds(180)
while ((Get-Date) -lt $deadline) {
  if (Test-InstallDirUnlocked) { break }
  Start-Sleep -Milliseconds 500
}

if (-not (Test-InstallDirUnlocked)) {
  Write-Log 'ERROR: archivos de instalación siguen bloqueados tras 180s. Se aborta sin tocar la instalación.'
  Start-Nexus
  Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue
  exit 1
}

# Margen extra para antivirus / indexador tras liberar handles.
Start-Sleep -Milliseconds 800

$restoreNeeded = $false
try {
  New-Item -ItemType Directory -Path $staging -Force | Out-Null

  # 2. Extraer el ZIP.
  Write-Log 'Extrayendo paquete...'
  $extracted = Join-Path $staging '__payload'
  New-Item -ItemType Directory -Path $extracted -Force | Out-Null
  Expand-Archive -LiteralPath $ZipPath -DestinationPath $extracted -Force

  # 3. Resolver la raíz real (el ZIP puede traer una carpeta contenedora).
  $source = $extracted
  $entries = @(Get-ChildItem -LiteralPath $extracted)
  if ($entries.Count -eq 1 -and $entries[0].PSIsContainer) {
    $source = $entries[0].FullName
    Write-Log ('Raíz del paquete: ' + $source)
  }

  # 4. Validar el payload ANTES de sobrescribir nada.
  if (-not (Test-Path -LiteralPath (Join-Path $source $ExeName))) {
    throw ('El paquete no contiene ' + $ExeName + '; se cancela la actualización.')
  }

  # 5. Backup de la instalación actual para poder revertir.
  Write-Log 'Creando backup de la instalación actual...'
  New-Item -ItemType Directory -Path $backup -Force | Out-Null
  Copy-Payload $InstallDir $backup

  # 6. Aplicar la actualización.
  Write-Log 'Aplicando archivos nuevos...'
  $restoreNeeded = $true
  Copy-Payload $source $InstallDir
  $restoreNeeded = $false
  Write-Log 'Actualización aplicada correctamente.'

  if (-not [string]::IsNullOrWhiteSpace($RemoteVersion)) {
    try {
      Set-Content -LiteralPath (Join-Path $InstallDir '.nexus-version') -Value $RemoteVersion.Trim() -Encoding UTF8
      Write-Log ('Versión registrada: ' + $RemoteVersion.Trim())
    } catch {
      Write-Log ('Aviso al escribir .nexus-version: ' + $_.Exception.Message)
    }
  }
} catch {
  Write-Log ('ERROR: ' + $_.Exception.Message)
  if ($restoreNeeded) {
    try {
      Write-Log 'Restaurando backup...'
      Copy-Payload $backup $InstallDir
      Write-Log 'Backup restaurado.'
    } catch {
      Write-Log ('ERROR CRÍTICO al restaurar el backup: ' + $_.Exception.Message)
    }
  }
} finally {
  # 7. Pase lo que pase, devolver al usuario una app funcional.
  Start-Nexus
  Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $ZipPath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $ReadyPath -Force -ErrorAction SilentlyContinue
  Write-Log '--- Fin de actualización ---'
  Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue
}
''';
