import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Solicita de una vez los permisos de runtime que la app necesita
/// (cámara para QR, micrófono para dictado, fotos/galería para leads).
///
/// Idempotente: si ya están concedidos, no muestra diálogos.
/// No incluye `REQUEST_INSTALL_PACKAGES` (OTA): ese se pide al instalar.
class AppPermissions {
  AppPermissions._();

  static bool _requestInFlight = false;

  /// Lista de permisos según plataforma.
  static List<Permission> get required {
    if (kIsWeb) return const [];
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const [
          Permission.camera,
          Permission.microphone,
          Permission.photos,
        ];
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const [
          Permission.camera,
          Permission.microphone,
          Permission.photos,
          Permission.speech,
        ];
      default:
        return const [];
    }
  }

  /// Pide todos los [required] que aún no estén concedidos.
  static Future<Map<Permission, PermissionStatus>> requestAll() async {
    if (kIsWeb || required.isEmpty) return const {};
    if (_requestInFlight) return const {};
    _requestInFlight = true;
    try {
      final pending = <Permission>[];
      for (final permission in required) {
        final status = await permission.status;
        if (!status.isGranted && !status.isLimited && !status.isRestricted) {
          pending.add(permission);
        }
      }
      if (pending.isEmpty) return const {};
      return pending.request();
    } finally {
      _requestInFlight = false;
    }
  }
}
