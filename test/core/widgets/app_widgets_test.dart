import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/theme/app_theme.dart';
import 'package:transworld_nexus/core/widgets/app_widgets.dart';
import 'package:transworld_nexus/core/widgets/tw_toast.dart';

void main() {
  tearDown(TwToast.hide);

  testWidgets('la confirmación destructiva exige una decisión explícita', (
    tester,
  ) async {
    bool? resultado;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                resultado = await confirmDialog(
                  context,
                  title: 'Desinstalar RegisPro',
                  message: 'Esta acción no se puede deshacer.',
                  confirmLabel: 'Desinstalar',
                  destructive: true,
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.text('Desinstalar RegisPro'), findsOneWidget);
    expect(find.text('Esta acción no se puede deshacer.'), findsOneWidget);
    expect(resultado, isNull);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('Desinstalar RegisPro'), findsOneWidget);
    expect(resultado, isNull);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Desinstalar RegisPro'), findsNothing);
    expect(resultado, isFalse);
  });

  testWidgets('el toast sin navbar se ancla al pie de la pantalla', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showAppSnackBar(context, 'Ya tienes la última versión.'),
              child: const Text('Mostrar'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mostrar'));
    await tester.pump();

    final toast = find.text('Ya tienes la última versión.');
    expect(toast, findsOneWidget);
    final positioned = tester.widget<Positioned>(
      find.ancestor(of: toast, matching: find.byType(Positioned)).first,
    );
    final safe = MediaQuery.paddingOf(tester.element(toast)).bottom;
    expect(positioned.bottom, TwToast.kBottom + safe);
  });

  testWidgets('el toast con navbar deja holgura sobre la barra flotante', (
    tester,
  ) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: ShellNavScope(
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      showAppSnackBar(context, 'Evento creado correctamente'),
                  child: const Text('Mostrar'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mostrar'));
      await tester.pump();

      final toast = find.text('Evento creado correctamente');
      expect(toast, findsOneWidget);
      final positioned = tester.widget<Positioned>(
        find.ancestor(of: toast, matching: find.byType(Positioned)).first,
      );
      final safe = MediaQuery.paddingOf(tester.element(toast)).bottom;
      expect(
        positioned.bottom,
        GlassNavTokens.occupiedHeightOf() +
            GlassNavTokens.deadZone +
            AppSpacing.sm +
            safe,
      );
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  });

  testWidgets('el toast en Windows no reserva la barra inferior', (
    tester,
  ) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: ShellNavScope(
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      showAppSnackBar(context, 'Evento creado correctamente'),
                  child: const Text('Mostrar'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mostrar'));
      await tester.pump();

      final toast = find.text('Evento creado correctamente');
      expect(toast, findsOneWidget);
      final positioned = tester.widget<Positioned>(
        find.ancestor(of: toast, matching: find.byType(Positioned)).first,
      );
      final safe = MediaQuery.paddingOf(tester.element(toast)).bottom;
      expect(positioned.bottom, TwToast.kBottom + safe);
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  });

  testWidgets('el toast en iOS deja holgura sobre el UITabBar nativo', (
    tester,
  ) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: ShellNavScope(
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      showAppSnackBar(context, 'Evento creado correctamente'),
                  child: const Text('Mostrar'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mostrar'));
      await tester.pump();

      final toast = find.text('Evento creado correctamente');
      expect(toast, findsOneWidget);
      final positioned = tester.widget<Positioned>(
        find.ancestor(of: toast, matching: find.byType(Positioned)).first,
      );
      final safe = MediaQuery.paddingOf(tester.element(toast)).bottom;
      expect(
        positioned.bottom,
        GlassNavTokens.nativeIosHeight + AppSpacing.sm + safe,
      );
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  });
}
