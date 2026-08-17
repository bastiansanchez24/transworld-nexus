import 'package:flutter_test/flutter_test.dart';

import 'package:transworld_nexus/features/updates/services/apk_installer.dart';

void main() {
  group('mapApkInstallFailure', () {
    test('firma distinta (conflict / update incompatible)', () {
      expect(
        mapApkInstallFailure(status: 4, legacyStatus: 0),
        contains('otra clave'),
      );
      expect(
        mapApkInstallFailure(status: 1, legacyStatus: -7),
        contains('otra clave'),
      );
    });

    test('build de depuración (testOnly)', () {
      expect(
        mapApkInstallFailure(status: 1, legacyStatus: -15),
        contains('depuración'),
      );
    });

    test('downgrade de versionCode', () {
      expect(
        mapApkInstallFailure(status: 1, legacyStatus: -25),
        contains('código de versión'),
      );
    });

    test('mensaje del sistema como fallback', () {
      expect(
        mapApkInstallFailure(
          status: 1,
          legacyStatus: 0,
          message: 'INSTALL_FAILED_INTERNAL_ERROR',
        ),
        'No se instaló la actualización. INSTALL_FAILED_INTERNAL_ERROR',
      );
    });
  });
}
