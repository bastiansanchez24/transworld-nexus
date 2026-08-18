import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/app.dart';
import 'package:transworld_nexus/core/config/app_bootstrap.dart';
import 'package:transworld_nexus/features/auth/screens/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('antes de bootstrap muestra splash y no monta el router', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appBootstrapProvider.overrideWith(
            (ref) => Completer<AppBootstrap>().future,
          ),
        ],
        child: const TransworldNexusApp(),
      ),
    );

    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
