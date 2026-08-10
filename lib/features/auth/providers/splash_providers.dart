import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Splash animado (Lottie) solo en Windows y Android.
///
/// En web (y demás plataformas) el router va directo a login/home sin
/// montar `/splash`.
bool get showAnimatedSplash {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.windows;
}

/// Se pone en `true` cuando el splash animado llega al hold (mark completo).
///
/// El router no abandona `/splash` hasta que esto sea true, para no cortar
/// el draw-on del logo en arranques rápidos. En plataformas sin animación
/// el gate del router ignora este flag.
final splashReadyProvider = StateProvider<bool>((ref) => false);

/// Se pone en `true` si, tras el hold del logo, la sesión/perfil no resolvió
/// a tiempo. Evita soft-lock cuando hay sesión restaurada pero el perfil
/// nunca emite data/error.
final splashNavigationTimedOutProvider = StateProvider<bool>((ref) => false);
