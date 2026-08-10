import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Solicita de una vez los permisos de runtime que la app necesita
/// (cámara para QR, micrófono para dictado, fotos/galería para leads,
/// instalar paquetes para OTA en Android).
///
/// Idempotente: si ya están concedidos, no muestra diálogos.
class AppPermissions {
  AppPermissions._();

  static bool _requestInFlight = false;

  /// Lista de permisos según plataforma.
  ///
  /// En Android, `requestInstallPackages` se pide al final y por separado:
  /// abre la pantalla del sistema (no un diálogo estándar).
  static List<Permission> get required {
    if (kIsWeb) return const [];
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const [
          Permission.camera,
          Permission.microphone,
          Permission.photos,
          Permission.notification,
          Permission.requestInstallPackages,
        ];
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const [
          Permission.camera,
          Permission.microphone,
          Permission.photos,
          Permission.speech,
          Permission.notification,
        ];
      default:
        return const [];
    }
  }

  static bool _needsRequest(PermissionStatus status) =>
      !status.isGranted && !status.isLimited && !status.isRestricted;

  /// Pide todos los [required] que aún no estén concedidos.
  static Future<Map<Permission, PermissionStatus>> requestAll() async {
    if (kIsWeb || required.isEmpty) return const {};
    if (_requestInFlight) return const {};
    _requestInFlight = true;
    try {
      final results = <Permission, PermissionStatus>{};
      final pending = <Permission>[];
      var askInstallPackages = false;

      for (final permission in required) {
        final status = await permission.status;
        if (!_needsRequest(status)) continue;
        if (permission == Permission.requestInstallPackages) {
          askInstallPackages = true;
          continue;
        }
        pending.add(permission);
      }

      if (pending.isNotEmpty) {
        results.addAll(await pending.request());
      }

      // Android OTA: pantalla "Permitir de esta fuente", después del resto.
      if (askInstallPackages) {
        results[Permission.requestInstallPackages] =
            await Permission.requestInstallPackages.request();
      }

      return results;
    } finally {
      _requestInFlight = false;
    }
  }
}
