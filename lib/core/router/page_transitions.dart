import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Safari (PWA de iPhone/iPad) anima el pop con el gesto de atrás del
/// historial. Si Flutter aplica SharedAxis encima, el menú de debajo
/// (evento / campaña) parpadea: el snapshot del gesto no coincide con la
/// página desplazada por [secondaryAnimation].
bool browserOwnsBackSwipe({
  bool? isWeb,
  TargetPlatform? platform,
}) {
  return (isWeb ?? kIsWeb) &&
      (platform ?? defaultTargetPlatform) == TargetPlatform.iOS;
}

/// Página push con SharedAxis horizontal (HANDOFF §5).
CustomTransitionPage<T> sharedAxisPage<T>({
  required LocalKey key,
  required Widget child,
  SharedAxisTransitionType type = SharedAxisTransitionType.horizontal,
}) {
  final browserBack = browserOwnsBackSwipe();
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: AppMotion.pushIn,
    reverseTransitionDuration: browserBack ? Duration.zero : AppMotion.pushIn,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final reduce = AppMotion.reduceMotion(context);
      if (reduce) {
        return FadeTransition(opacity: animation, child: child);
      }
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: browserBack
            ? const AlwaysStoppedAnimation<double>(0)
            : secondaryAnimation,
        transitionType: type,
        fillColor: AppColors.background,
        child: child,
      );
    },
  );
}

Widget fadeThroughSwitcher({
  required Widget child,
  required int index,
}) {
  return PageTransitionSwitcher(
    duration: AppMotion.screenIn,
    transitionBuilder: (child, animation, secondaryAnimation) {
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
    },
    child: KeyedSubtree(
      key: ValueKey(index),
      child: child,
    ),
  );
}
