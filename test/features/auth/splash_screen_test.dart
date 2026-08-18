import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:transworld_nexus/core/theme/app_theme.dart';
import 'package:transworld_nexus/features/auth/providers/splash_providers.dart';
import 'package:transworld_nexus/features/auth/screens/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SplashScreen renders looping Lottie on brand background', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SplashScreen(armProfileTimeout: true)),
      ),
    );

    expect(find.byType(Scaffold), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.background);
    expect(find.byType(Lottie), findsOneWidget);

    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('splashReady is true on first frame, without waiting animation', (
    tester,
  ) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const MaterialApp(
              home: SplashScreen(armProfileTimeout: true),
            );
          },
        ),
      ),
    );

    expect(container.read(splashReadyProvider), isTrue);
    expect(container.read(splashNavigationTimedOutProvider), isFalse);

    await tester.pump(const Duration(milliseconds: 2500));
    expect(container.read(splashReadyProvider), isTrue);
    expect(container.read(splashNavigationTimedOutProvider), isFalse);

    await tester.pump(const Duration(seconds: 8));
    expect(container.read(splashNavigationTimedOutProvider), isTrue);
  });
}
