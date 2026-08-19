import 'package:flutter_test/flutter_test.dart';

import 'package:transworld_nexus/data/models/github_release.dart';

GitHubRelease _release({
  required String tagName,
  required List<GitHubReleaseAsset> assets,
}) {
  return GitHubRelease(
    tagName: tagName,
    name: 'RegisPro $tagName',
    body: 'Notas',
    prerelease: false,
    assets: assets,
  );
}

GitHubReleaseAsset _asset(String name, {int size = 1000, String? digest}) {
  return GitHubReleaseAsset(
    name: name,
    size: size,
    browserDownloadUrl: 'https://example.com/$name',
    digest: digest,
  );
}

void main() {
  group('resolveNexusWindowsZip', () {
    test('prefiere el nombre exacto RegisPro del tag', () {
      final release = _release(
        tagName: 'v1.4.0',
        assets: [
          _asset('windows-regispro-v1.3.0.zip', size: 9000),
          _asset('windows-regispro-v1.4.0.zip', size: 1000),
        ],
      );

      expect(
        release.resolveNexusWindowsZip()?.name,
        'windows-regispro-v1.4.0.zip',
      );
    });

    test('prefiere regispro sobre nexus legacy con el mismo tag', () {
      final release = _release(
        tagName: 'v1.4.0',
        assets: [
          _asset('windows-nexus-v1.4.0.zip', size: 9000),
          _asset('windows-regispro-v1.4.0.zip', size: 1000),
        ],
      );

      expect(
        release.resolveNexusWindowsZip()?.name,
        'windows-regispro-v1.4.0.zip',
      );
    });

    test('acepta windows-nexus legacy si no hay regispro', () {
      final release = _release(
        tagName: 'v1.4.0',
        assets: [
          _asset('windows-NEXUS-v1.3.0.zip', size: 9000),
          _asset('windows-NEXUS-v1.4.0.zip', size: 1000),
        ],
      );

      expect(
        release.resolveNexusWindowsZip()?.name,
        'windows-NEXUS-v1.4.0.zip',
      );
    });

    test('elige el zip más grande si no hay coincidencia exacta', () {
      final release = _release(
        tagName: 'v2.0.0',
        assets: [
          _asset('windows-regispro-v2.0.0-beta.zip', size: 5000),
          _asset('windows-regispro-v2.0.0.zip', size: 8000),
        ],
      );

      expect(
        release.resolveNexusWindowsZip()?.name,
        'windows-regispro-v2.0.0.zip',
      );
    });

    test('sin zip de app retorna null (no fallback genérico)', () {
      final release = _release(
        tagName: 'v1.0.0',
        assets: [
          _asset('bundle.zip', size: 2000),
          _asset('NexusBootstrap.zip', size: 4000),
        ],
      );

      expect(release.resolveNexusWindowsZip(), isNull);
    });
  });

  group('resolveNexusAsset', () {
    test('delega a Android o Windows según plataforma', () {
      final release = _release(
        tagName: 'v1.0.0',
        assets: [
          _asset('android-regispro-v1.0.0.apk'),
          _asset('windows-regispro-v1.0.0.zip'),
        ],
      );

      expect(
        release.resolveNexusAsset(forWindows: false)?.name,
        'android-regispro-v1.0.0.apk',
      );
      expect(
        release.resolveNexusAsset(forWindows: true)?.name,
        'windows-regispro-v1.0.0.zip',
      );
    });

    test('nunca cruza el APK con el ZIP de Windows', () {
      final soloApk = _release(
        tagName: 'v1.0.0',
        assets: [_asset('android-regispro-v1.0.0.apk')],
      );
      expect(soloApk.resolveNexusAsset(forWindows: true), isNull);

      final soloZip = _release(
        tagName: 'v1.0.0',
        assets: [_asset('windows-regispro-v1.0.0.zip')],
      );
      expect(soloZip.resolveNexusAsset(forWindows: false), isNull);
    });

    test('ignora el .zip de símbolos de depuración si hay uno de RegisPro', () {
      final release = _release(
        tagName: 'v1.0.0',
        assets: [
          _asset('debug-symbols.zip', size: 90000),
          _asset('windows-regispro-v1.0.0.zip', size: 1000),
        ],
      );

      expect(
        release.resolveNexusAsset(forWindows: true)?.name,
        'windows-regispro-v1.0.0.zip',
      );
    });

    test('ignora NexusBootstrap.zip aunque contenga nexus en el nombre', () {
      final release = _release(
        tagName: 'v1.0.0',
        assets: [
          _asset('NexusBootstrap.zip', size: 50000),
          _asset('windows-regispro-v1.0.0.zip', size: 1000),
        ],
      );

      expect(
        release.resolveNexusWindowsZip()?.name,
        'windows-regispro-v1.0.0.zip',
      );
      expect(_asset('NexusBootstrap.zip').isNexusWindowsZip, isFalse);
    });

    test('solo NexusBootstrap.zip no cuenta como paquete de app', () {
      final release = _release(
        tagName: 'v1.0.0',
        assets: [_asset('NexusBootstrap.zip', size: 50000)],
      );

      expect(release.resolveNexusWindowsZip(), isNull);
    });
  });

  group('digest del asset Windows', () {
    test('expone el sha256 en hex cuando GitHub lo entrega', () {
      final hex = 'a' * 64;
      final asset = _asset(
        'windows-regispro-v1.0.0.zip',
        digest: 'sha256:$hex',
      );
      expect(asset.sha256Hex, hex);
    });

    test('sha256Hex es null si no hay digest', () {
      expect(_asset('windows-regispro-v1.0.0.zip').sha256Hex, isNull);
    });
  });
}
