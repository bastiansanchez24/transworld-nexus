import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/widgets/main_shell_scaffold.dart';

void main() {
  test('el diálogo de cierre pertenece únicamente a Android nativo', () {
    expect(
      shellConfirmsNativeExit(isWeb: false, platform: TargetPlatform.android),
      isTrue,
    );
    expect(
      shellConfirmsNativeExit(isWeb: false, platform: TargetPlatform.windows),
      isFalse,
    );
    expect(
      shellConfirmsNativeExit(isWeb: true, platform: TargetPlatform.windows),
      isFalse,
    );
    expect(
      shellConfirmsNativeExit(isWeb: false, platform: TargetPlatform.iOS),
      isFalse,
    );
  });
}
