import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

const _installChannel = MethodChannel('com.transworld.nexus/apk_installer');

/// Resultado de intentar instalar un APK sideload.
enum ApkInstallOutcome {
  launched,
  permissionRequired,
  unsupportedPlatform,
  failed,
}

class ApkInstallResult {
  const ApkInstallResult(this.outcome, {this.message});

  final ApkInstallOutcome outcome;
  final String? message;
}

bool _isSignatureMismatch({
  required int status,
  required int legacyStatus,
  required String message,
}) {
  final detail = message.toUpperCase();
  return status == 4 ||
      legacyStatus == -7 ||
      detail.contains('UPDATE_INCOMPATIBLE') ||
      detail.contains('SIGNATURES DO NOT MATCH');
}

/// Traduce el status de [PackageInstaller] / códigos legacy a un mensaje.
String mapApkInstallFailure({
  required int status,
  required int legacyStatus,
  String message = '',
}) {
  // Android 14+ a menudo reporta UPDATE_INCOMPATIBLE como status 5
  // (INCOMPATIBLE) en vez de 4 (CONFLICT). Mirar la firma primero.
  if (_isSignatureMismatch(
    status: status,
    legacyStatus: legacyStatus,
    message: message,
  )) {
    return 'No se pudo instalar: la app actual está firmada con otra clave. '
        'Desinstala RegisPro e instala esta actualización.';
  }

  switch (legacyStatus) {
    case -15: // INSTALL_FAILED_TEST_ONLY
      return 'No se pudo instalar: la app actual es un build de depuración '
          '(flutter run). Desinstálala e instala el APK de la Release.';
    case -25: // INSTALL_FAILED_VERSION_DOWNGRADE
      return 'No se pudo instalar: el código de versión no es mayor que el '
          'instalado.';
    case -103: // INSTALL_PARSE_FAILED_NO_CERTIFICATES
      return 'El APK no tiene una firma válida.';
    case -113: // INSTALL_FAILED_NO_MATCHING_ABIS
      return 'Este paquete no incluye bibliotecas para este dispositivo.';
    case -9: // INSTALL_FAILED_OLDER_SDK
      return 'Este paquete requiere una versión de Android más reciente.';
  }

  switch (status) {
    case 2: // STATUS_FAILURE_ABORTED
      return 'Instalación cancelada.';
    case 3: // STATUS_FAILURE_BLOCKED
      return 'El sistema bloqueó la instalación. Revisa el permiso de '
          'instalar aplicaciones desconocidas.';
    case 5: // STATUS_FAILURE_INCOMPATIBLE
      return 'Este paquete no es compatible con el dispositivo.';
    case 6: // STATUS_FAILURE_INVALID
      return 'El APK descargado es inválido o está dañado.';
    case 7: // STATUS_FAILURE_STORAGE
      return 'No hay espacio suficiente para instalar la actualización.';
  }

  final detail = message.trim();
  if (detail.isNotEmpty) {
    return 'No se instaló la actualización. $detail';
  }
  return 'No se instaló la actualización.';
}

/// Instala un APK descargado con [PackageInstaller] (y OpenFilex de respaldo).
class ApkInstaller {
  static const installPermissionMessage =
      'Para actualizar RegisPro debes permitir la instalación de aplicaciones. '
      'Activa el permiso en Configuración y vuelve a intentar.';

  /// Solo consulta el estado (sin abrir pantallas del sistema).
  Future<bool> hasInstallPermission() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    return (await Permission.requestInstallPackages.status).isGranted;
  }

  /// Comprueba / solicita permiso de instalar paquetes desconocidos.
  Future<bool> ensureInstallPermission() async {
    if (kIsWeb || !Platform.isAndroid) return false;

    if (await hasInstallPermission()) return true;

    final requested = await Permission.requestInstallPackages.request();
    return requested.isGranted;
  }

  /// Abre la pantalla del sistema para permitir instalar desde RegisPro.
  ///
  /// En Android 8+ es la ruta correcta (no el detalle genérico de la app).
  Future<bool> openInstallSettings() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    final status = await Permission.requestInstallPackages.request();
    if (status.isGranted) return true;
    // Fallback si el OEM no abre la pantalla especial.
    return openAppSettings();
  }

  /// Instala [apkFile] y espera el resultado del sistema.
  Future<ApkInstallResult> install(File apkFile) async {
    if (kIsWeb || !Platform.isAndroid) {
      return const ApkInstallResult(
        ApkInstallOutcome.unsupportedPlatform,
        message: 'Las actualizaciones OTA solo están disponibles en Android.',
      );
    }

    if (!await apkFile.exists()) {
      return const ApkInstallResult(
        ApkInstallOutcome.failed,
        message: 'No se encontró el APK descargado.',
      );
    }

    final allowed = await ensureInstallPermission();
    if (!allowed) {
      return const ApkInstallResult(
        ApkInstallOutcome.permissionRequired,
        message: installPermissionMessage,
      );
    }

    try {
      final raw = await _installChannel.invokeMethod<dynamic>('installApk', {
        'path': apkFile.path,
      });
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final ok = map['ok'] == true;
        final status = (map['status'] as num?)?.toInt() ?? 1;
        final legacyStatus = (map['legacyStatus'] as num?)?.toInt() ?? 0;
        if (ok) {
          return const ApkInstallResult(ApkInstallOutcome.launched);
        }
        return ApkInstallResult(
          ApkInstallOutcome.failed,
          message: mapApkInstallFailure(
            status: status,
            legacyStatus: legacyStatus,
            message: map['message'] as String? ?? '',
          ),
        );
      }
    } on MissingPluginException {
      // Tests / builds sin el channel nativo.
    } on PlatformException catch (e) {
      return ApkInstallResult(
        ApkInstallOutcome.failed,
        message: e.message ?? 'No se pudo iniciar la instalación.',
      );
    }

    return _installWithOpenFilex(apkFile);
  }

  Future<ApkInstallResult> _installWithOpenFilex(File apkFile) async {
    final result = await OpenFilex.open(
      apkFile.path,
      type: 'application/vnd.android.package-archive',
    );

    switch (result.type) {
      case ResultType.done:
        return const ApkInstallResult(ApkInstallOutcome.launched);
      case ResultType.noAppToOpen:
        return const ApkInstallResult(
          ApkInstallOutcome.failed,
          message:
              'No hay instalador de paquetes disponible en el dispositivo.',
        );
      case ResultType.permissionDenied:
        return const ApkInstallResult(
          ApkInstallOutcome.permissionRequired,
          message: installPermissionMessage,
        );
      case ResultType.fileNotFound:
        return const ApkInstallResult(
          ApkInstallOutcome.failed,
          message: 'El archivo APK ya no existe.',
        );
      case ResultType.error:
        return ApkInstallResult(
          ApkInstallOutcome.failed,
          message: result.message.isNotEmpty
              ? result.message
              : 'No se pudo abrir el instalador.',
        );
    }
  }
}
