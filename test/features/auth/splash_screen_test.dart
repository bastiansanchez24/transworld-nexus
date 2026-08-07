import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:transworld_nexus/core/theme/app_theme.dart';
import 'package:transworld_nexus/features/auth/providers/splash_providers.dart';
import 'package:transworld_nexus/features/auth/screens/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SplashScreen renders Lottie on brand background', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SplashScreen()),
      ),
    );

    expect(find.byType(Scaffold), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.background);
    expect(find.byType(Lottie), findsOneWidget);

    // Completa el fallback timer para no dejar timers pendientes.
    await tester.pump(const Duration(milliseconds: 2500));
  });

  testWidgets('splashReady becomes true after fallback timeout', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const MaterialApp(home: SplashScreen());
          },
        ),
      ),
    );

    expect(container.read(splashReadyProvider), isFalse);

    await tester.pump(const Duration(milliseconds: 2500));

    expect(container.read(splashReadyProvider), isTrue);
  });
}
