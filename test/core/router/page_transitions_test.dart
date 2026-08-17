import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('fuera de la PWA de iOS el pop conserva la duración del SharedAxis', () {
    final page = sharedAxisPage(
      key: const ValueKey('hub'),
      child: const SizedBox(),
    );
    expect(page.reverseTransitionDuration, AppMotion.pushIn);
  });
}
