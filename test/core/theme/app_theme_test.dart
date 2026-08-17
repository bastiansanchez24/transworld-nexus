import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppColors ancla navy y lima del logo Transworld', () {
    expect(AppColors.primary, const Color(0xFF203E6D));
    expect(AppColors.primaryDeep, const Color(0xFF162B4C));
    expect(AppColors.primaryLight, const Color(0xFF2E568F));
    expect(AppColors.accent, const Color(0xFFB1F22A));
    expect(AppColors.accentGlow, const Color(0xFFA0DE2A));
    expect(AppColors.successTint, AppColors.tintLime);
    expect(AppColors.toastCheck, AppColors.accent);
  });

  testWidgets('ThemeData light usa brand colors en ColorScheme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SizedBox.shrink()),
    );

    final scheme = Theme.of(tester.element(find.byType(SizedBox))).colorScheme;
    expect(scheme.primary, AppColors.primary);
    expect(scheme.tertiary, AppColors.accent);
    expect(scheme.onTertiary, AppColors.primaryDeep);
    expect(scheme.tertiaryContainer, AppColors.tintLime);
  });

  test('usesSideRail solo en Windows de escritorio', () {
    final previous = debugDefaultTargetPlatformOverride;
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(GlassNavTokens.usesSideRail, isFalse);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(GlassNavTokens.usesSideRail, isFalse);

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(GlassNavTokens.usesSideRail, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  });

  testWidgets('contentBottomInset no reserva la tab bar en Windows', (
    tester,
  ) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(1280, 720)),
          child: SizedBox(),
        ),
      );
      final context = tester.element(find.byType(SizedBox));
      expect(GlassNavTokens.contentBottomInset(context), AppSpacing.xl);
      expect(AppSpacing.shellFabBottomOf(), AppSpacing.sm);
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  });

  testWidgets('contentBottomInset reserva la tab bar flotante en Android', (
    tester,
  ) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(390, 844)),
          child: SizedBox(),
        ),
      );
      final context = tester.element(find.byType(SizedBox));
      expect(
        GlassNavTokens.contentBottomInset(context),
        GlassNavTokens.occupiedHeightOf() +
            GlassNavTokens.deadZone +
            AppSpacing.xl,
      );
      expect(
        AppSpacing.shellFabBottomOf(),
        GlassNavTokens.occupiedHeightOf() + AppSpacing.sm,
      );
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  });
}
