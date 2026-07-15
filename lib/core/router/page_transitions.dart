import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Página push con SharedAxis horizontal (HANDOFF §5).
CustomTransitionPage<T> sharedAxisPage<T>({
  required LocalKey key,
  required Widget child,
  SharedAxisTransitionType type = SharedAxisTransitionType.horizontal,
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
