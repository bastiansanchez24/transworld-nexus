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
        ];
      default:
        return const [];
    }
  }

  /// Permisos aplicables a una sesión concreta.
  ///
  /// Los usuarios externos no tienen acceso al módulo de notificaciones, por
  /// lo que tampoco se les debe mostrar el prompt del sistema operativo. El
  /// permiso OTA sí aplica a todas las sesiones autenticadas en Android.
  static List<Permission> requiredFor({
    required bool includeNotifications,
    bool includeAppUpdates = true,
  }) {
    return required.where((permission) {
      if (!includeNotifications && permission == Permission.notification) {
        return false;
      }
      if (!includeAppUpdates &&
          permission == Permission.requestInstallPackages) {
        return false;
      }
      return true;
    }).toList();
  }

  static bool _needsRequest(PermissionStatus status) =>
      !status.isGranted && !status.isLimited && !status.isRestricted;

  /// Pide todos los [required] que aún no estén concedidos.
  static Future<Map<Permission, PermissionStatus>> requestAll({
    bool includeNotifications = true,
    bool includeAppUpdates = true,
  }) => _request(
    requiredFor(
      includeNotifications: includeNotifications,
      includeAppUpdates: includeAppUpdates,
    ),
  );

  static Future<Map<Permission, PermissionStatus>> requestNotifications() =>
      _request(
        required
            .where((permission) => permission == Permission.notification)
            .toList(),
      );

  /// Pantalla del sistema "Permitir de esta fuente". Va al final del
  /// onboarding y otra vez al tocar Actualizar si todavía no está concedido.
  static Future<Map<Permission, PermissionStatus>> requestInstallPackages() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return Future.value(const {});
    }
    return _request(const [Permission.requestInstallPackages]);
  }

  static Future<Map<Permission, PermissionStatus>> _request(
    List<Permission> permissions,
  ) async {
    if (kIsWeb || permissions.isEmpty) return const {};
    if (_requestInFlight) return const {};
    _requestInFlight = true;
    try {
      final results = <Permission, PermissionStatus>{};
      final pending = <Permission>[];
      var askInstallPackages = false;

      for (final permission in permissions) {
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
        results[Permission.requestInstallPackages] = await Permission
            .requestInstallPackages
            .request();
      }

      return results;
    } finally {
      _requestInFlight = false;
    }
  }
}
