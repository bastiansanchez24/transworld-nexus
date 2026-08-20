import 'dart:io';

import 'package:flutter/foundation.dart';

/// Plataformas donde el flujo OTA vía GitHub Releases está habilitado.
bool otaUpdatesSupportedFor(TargetPlatform platform, {required bool isWeb}) {
  if (isWeb) return false;
  return platform == TargetPlatform.android ||
      platform == TargetPlatform.windows;
}

bool get otaUpdatesSupported =>
    otaUpdatesSupportedFor(defaultTargetPlatform, isWeb: kIsWeb);

String get otaUnsupportedMessage {
  if (kIsWeb) {
    return 'Las actualizaciones OTA no están disponibles en la versión web.';
  }
  return 'Las actualizaciones OTA solo están disponibles en Android y Windows.';
}

String get otaInstallingLabel {
  if (otaResolvesWindowsAsset) return 'Aplicando actualización…';
  return 'Abriendo instalador…';
}

bool get otaResolvesWindowsAsset {
  if (kIsWeb) return false;
  return Platform.isWindows;
}

/// Desinstalación desde el menú de la app (script bootstrap en Windows).
bool get canUninstallApp {
  if (kIsWeb) return false;
  return Platform.isWindows;
}
