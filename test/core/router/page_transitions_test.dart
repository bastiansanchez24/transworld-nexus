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
    'en Android, Windows o Flutter nativo el SharedAxis sigue animando el pop',
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
