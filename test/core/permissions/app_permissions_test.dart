import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:transworld_nexus/core/permissions/app_permissions.dart';

void main() {
  test(
    'sesión externa conserva captura y excluye notificaciones del lote inicial',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final permissions = AppPermissions.requiredFor(
        includeNotifications: false,
        includeAppUpdates: false,
      );

      expect(permissions, contains(Permission.camera));
      expect(permissions, contains(Permission.microphone));
      expect(permissions, contains(Permission.photos));
      expect(permissions, isNot(contains(Permission.notification)));
      expect(permissions, isNot(contains(Permission.requestInstallPackages)));
    },
  );

  test('en Android el permiso de instalar queda al final de la lista', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(AppPermissions.required.last, Permission.requestInstallPackages);
    expect(
      AppPermissions.requiredFor(
        includeNotifications: true,
        includeAppUpdates: true,
      ).last,
      Permission.requestInstallPackages,
    );
    expect(
      AppPermissions.requiredFor(
        includeNotifications: false,
        includeAppUpdates: false,
      ),
      isNot(contains(Permission.requestInstallPackages)),
    );
  });

  test('externo en Android pide OTA y no el permiso de notificaciones', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final permissions = AppPermissions.requiredFor(
      includeNotifications: false,
      includeAppUpdates: true,
    );

    expect(permissions, contains(Permission.camera));
    expect(permissions, contains(Permission.requestInstallPackages));
    expect(permissions, isNot(contains(Permission.notification)));
  });

  test('en iOS no se pide el permiso de notificaciones del sistema', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(AppPermissions.required, isNot(contains(Permission.notification)));
    expect(
      AppPermissions.requiredFor(includeNotifications: true),
      isNot(contains(Permission.notification)),
    );
  });
}
