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

  testWidgets('descartar creación: Cancelar se queda, Descartar confirma', (
    tester,
  ) async {
    bool? resultado;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                resultado = await confirmDiscardCreate(context);
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(resultado, isFalse);

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(resultado, isTrue);
  });

  testWidgets('guardar cambios: tres acciones', (tester) async {
    FormExitAction? resultado;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                resultado = await confirmSaveEdits(context);
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('¿Guardar los cambios?'), findsOneWidget);

    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(resultado, FormExitAction.stay);

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(resultado, FormExitAction.discard);

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(resultado, FormExitAction.save);
  });

  testWidgets('el vacío muestra Actualizar debajo del aviso', (tester) async {
    var refrescos = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: EmptyStateView(
          message: 'Aún no hay asistentes registrados.',
          onRefresh: () => refrescos++,
        ),
      ),
    );

    final aviso = find.text('Aún no hay asistentes registrados.');
    final actualizar = find.text('Actualizar');
    expect(aviso, findsOneWidget);
    expect(actualizar, findsOneWidget);
    expect(
      tester.getTopLeft(actualizar).dy,
      greaterThan(tester.getBottomLeft(aviso).dy),
    );

    await tester.tap(actualizar);
    expect(refrescos, 1);
  });

  testWidgets(
    'en Android e iOS el aviso vacío queda más arriba que en escritorio',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Future<double> centroDelAviso(TargetPlatform platform) async {
        final previous = debugDefaultTargetPlatformOverride;
        debugDefaultTargetPlatformOverride = platform;
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 200)),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyStateView(
                      message: 'Aún no hay asistentes registrados.',
                      onRefresh: () {},
                    ),
                  ),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();
          return tester
              .getCenter(find.text('Aún no hay asistentes registrados.'))
              .dy;
        } finally {
          debugDefaultTargetPlatformOverride = previous;
        }
      }

      final yAndroid = await centroDelAviso(TargetPlatform.android);
      final yIos = await centroDelAviso(TargetPlatform.iOS);
      final yWindows = await centroDelAviso(TargetPlatform.windows);

      expect(yAndroid, lessThan(yWindows));
      expect(yIos, lessThan(yWindows));
    },
  );
}
