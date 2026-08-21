import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart' show CupertinoPage;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Safari (PWA de iPhone/iPad) anima el pop con el gesto de atrás del
/// historial. Si Flutter aplica SharedAxis encima, el menú de debajo
/// (evento / evento de leads) parpadea: el snapshot del gesto no coincide con la
/// página desplazada por [secondaryAnimation].
bool browserOwnsBackSwipe({bool? isWeb, TargetPlatform? platform}) {
  return (isWeb ?? kIsWeb) &&
      (platform ?? defaultTargetPlatform) == TargetPlatform.iOS;
}

/// En iOS/macOS nativo el pop interactivo (deslizar desde el borde) solo lo
/// instala [CupertinoPage]. [CustomTransitionPage] sustituye la transición
/// del tema y se queda sin el detector del borde.
bool cupertinoOwnsBackSwipe({bool? isWeb, TargetPlatform? platform}) {
  if (isWeb ?? kIsWeb) return false;
  final resolved = platform ?? defaultTargetPlatform;
  return resolved == TargetPlatform.iOS || resolved == TargetPlatform.macOS;
}

/// Página push separada por plataforma: Cupertino en iOS nativo, SharedAxis
/// en Android, transición corta en Windows e historial sin animación inversa
/// adicional en Web.
Page<T> sharedAxisPage<T>({
  required LocalKey key,
  required Widget child,
  SharedAxisTransitionType type = SharedAxisTransitionType.horizontal,
  bool? isWeb,
  TargetPlatform? platform,
}) {
  if (cupertinoOwnsBackSwipe(isWeb: isWeb, platform: platform)) {
    return CupertinoPage<T>(key: key, child: child);
  }

  final resolvedIsWeb = isWeb ?? kIsWeb;
  if (resolvedIsWeb) {
    return _webPage(key: key, child: child);
  }

  final resolvedPlatform = platform ?? defaultTargetPlatform;
  if (resolvedPlatform == TargetPlatform.windows) {
    return _windowsPage(key: key, child: child);
  }

  return _androidAndFallbackPage(key: key, child: child, type: type);
}

CustomTransitionPage<T> _androidAndFallbackPage<T>({
  required LocalKey key,
  required Widget child,
  required SharedAxisTransitionType type,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: AppMotion.pushIn,
    reverseTransitionDuration: AppMotion.pushIn,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final reduce = AppMotion.reduceMotion(context);
      if (reduce) {
        return FadeTransition(opacity: animation, child: child);
      }
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: type,
        fillColor: AppColors.background,
        child: child,
      );
    },
  );
}

CustomTransitionPage<T> _windowsPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    transitionsBuilder: (context, animation, _, child) {
      if (AppMotion.reduceMotion(context)) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.ease,
        reverseCurve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.035, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

CustomTransitionPage<T> _webPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 160),
    // El historial del navegador ya representa visualmente el back. Una
    // segunda transición inversa es la que se percibe como "salir y volver".
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (context, animation, _, child) {
      if (AppMotion.reduceMotion(context)) return child;
      final curved = CurvedAnimation(parent: animation, curve: AppMotion.ease);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.02, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

Widget fadeThroughSwitcher({required Widget child, required int index}) {
  return PageTransitionSwitcher(
    duration: AppMotion.screenIn,
    transitionBuilder: (child, animation, secondaryAnimation) {
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
    },
    child: KeyedSubtree(key: ValueKey(index), child: child),
  );
}
