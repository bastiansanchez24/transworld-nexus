import 'package:flutter/cupertino.dart' show CupertinoPage;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:transworld_nexus/core/router/page_transitions.dart';
import 'package:transworld_nexus/core/theme/app_theme.dart';

void main() {
  test('Safari en iPhone se queda con el gesto de atrás', () {
    expect(
      browserOwnsBackSwipe(isWeb: true, platform: TargetPlatform.iOS),
      isTrue,
    );
  });

  test(
    'solo Safari iOS delega específicamente el gesto de borde al navegador',
    () {
      expect(
        browserOwnsBackSwipe(isWeb: true, platform: TargetPlatform.android),
        isFalse,
      );
      expect(
        browserOwnsBackSwipe(isWeb: false, platform: TargetPlatform.iOS),
        isFalse,
      );
    },
  );

  test('iOS nativo usa Cupertino para el gesto de deslizar atrás', () {
    expect(
      cupertinoOwnsBackSwipe(isWeb: false, platform: TargetPlatform.iOS),
      isTrue,
    );
    expect(
      cupertinoOwnsBackSwipe(isWeb: false, platform: TargetPlatform.macOS),
      isTrue,
    );
    expect(
      cupertinoOwnsBackSwipe(isWeb: true, platform: TargetPlatform.iOS),
      isFalse,
    );
    expect(
      cupertinoOwnsBackSwipe(isWeb: false, platform: TargetPlatform.android),
      isFalse,
    );
  });

  test('fuera de la PWA de iOS el pop conserva la duración del SharedAxis', () {
    final page = sharedAxisPage(
      key: const ValueKey('hub'),
      child: const SizedBox(),
      isWeb: false,
      platform: TargetPlatform.android,
    );
    expect(page, isA<CustomTransitionPage<void>>());
    expect(
      (page as CustomTransitionPage<void>).reverseTransitionDuration,
      AppMotion.pushIn,
    );
  });

  test('Windows usa una transición breve independiente de Android', () {
    final page =
        sharedAxisPage(
              key: const ValueKey('windows'),
              child: const SizedBox(),
              isWeb: false,
              platform: TargetPlatform.windows,
            )
            as CustomTransitionPage<void>;

    expect(page.transitionDuration, const Duration(milliseconds: 180));
    expect(page.reverseTransitionDuration, const Duration(milliseconds: 160));
  });

  test('Web no agrega una animación inversa al historial del navegador', () {
    final page =
        sharedAxisPage(
              key: const ValueKey('web'),
              child: const SizedBox(),
              isWeb: true,
              platform: TargetPlatform.windows,
            )
            as CustomTransitionPage<void>;

    expect(page.transitionDuration, const Duration(milliseconds: 160));
    expect(page.reverseTransitionDuration, Duration.zero);
  });

  test('en iOS nativo la ruta push es CupertinoPage', () {
    final page = sharedAxisPage(
      key: const ValueKey('hub'),
      child: const SizedBox(),
      isWeb: false,
      platform: TargetPlatform.iOS,
    );
    expect(page, isA<CupertinoPage<void>>());
  });
}
