import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

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

/// Instala un APK descargado abriendo el instalador del sistema.
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

  /// Lanza el instalador del sistema sobre [apkFile].
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
          message: 'No hay instalador de paquetes disponible en el dispositivo.',
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
