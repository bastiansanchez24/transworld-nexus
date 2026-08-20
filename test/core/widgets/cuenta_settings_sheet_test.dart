import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/network/offline_policy.dart';
import 'package:transworld_nexus/core/widgets/cuenta_settings_sheet.dart';
import 'package:transworld_nexus/features/updates/services/update_platform.dart';

void main() {
  testWidgets('cerrar sesión pide confirmación destructiva', (tester) async {
    var cerro = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCuentaSettingsSheet(
                context: context,
                onMiPerfil: () {},
                onSincronizacion: () {},
                onActualizaciones: () {},
                onCerrarSesion: () => cerro = true,
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(cuentaLogoutButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Cerrar sesión'), findsWidgets);
    expect(find.text('¿Está seguro que desea cerrar sesión?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(cerro, isFalse);

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(cuentaLogoutButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(cerro, isTrue);
  });

  testWidgets('el sheet oculta Sincronización fuera de móvil y limita su alto', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCuentaSettingsSheet(
                context: context,
                onMiPerfil: () {},
                onSincronizacion: () {},
                onActualizaciones: () {},
                onCerrarSesion: () {},
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    if (supportsOfflineCacheAqui) {
      expect(find.text('Sincronización'), findsOneWidget);
    } else {
      expect(find.text('Sincronización'), findsNothing);
    }
    expect(
      find.text(
        otaUpdatesSupported ? 'Actualizaciones' : 'Historial de versiones',
      ),
      findsOneWidget,
    );

    final altoMax = tester
        .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
        .map((b) => b.constraints.maxHeight)
        .where((h) => h.isFinite);
    expect(
      altoMax.any((h) => (h - 600 * 0.58).abs() < 1),
      isTrue,
    );
  });

  testWidgets('en iOS el tile de actualizaciones es historial', (tester) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showCuentaSettingsSheet(
                  context: context,
                  onMiPerfil: () {},
                  onSincronizacion: () {},
                  onActualizaciones: () {},
                  onCerrarSesion: () {},
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Historial de versiones'), findsOneWidget);
      expect(find.text('Actualizaciones'), findsNothing);
      expect(find.text('Sincronización'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  });
}
