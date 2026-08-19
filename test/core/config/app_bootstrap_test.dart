import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/app.dart';
import 'package:transworld_nexus/core/config/app_bootstrap.dart';
import 'package:transworld_nexus/features/auth/screens/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('antes de bootstrap muestra splash sin el router de la app', (
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
    // Router de bootstrap: si usáramos `MaterialApp(home:)`, en Chrome el
    // historial pasa a una sola entrada y el botón atrás deja de navegar.
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.routerConfig, isNotNull);
    expect(app.home, isNull);
  });
}
