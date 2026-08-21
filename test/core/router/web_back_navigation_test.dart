import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:transworld_nexus/core/router/browser_history.dart';
import 'package:transworld_nexus/core/router/refresh_on_visible.dart';

/// Historial del navegador de mentira.
///
/// Recoge lo que go_router reporta al motor (`routeInformationUpdated`, con su
/// bandera `replace`) y sabe reproducir un `popstate`, que es como llega de
/// vuelta el botón atrás —o el lateral del mouse— a `didPushRouteInformation`.
/// Sin esto el camino de web no se puede probar en la VM.
class _HistorialFalso {
  final entradas = <RouteInformation>[];
  final saltos = <int>[];
  GoRouter? router;

  void instalar() {
    entradas.clear();
    saltos.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.navigation, (call) async {
      if (call.method == 'routeInformationUpdated') {
        final args = call.arguments as Map<Object?, Object?>;
        final info = RouteInformation(
          uri: Uri.parse(args['uri'] as String),
          state: args['state'],
        );
        if (args['replace'] as bool && entradas.isNotEmpty) {
          entradas[entradas.length - 1] = info;
        } else {
          entradas.add(info);
        }
      }
      return null;
    });
    retrocesoDeHistorialParaPruebas = (pasos) {
      saltos.add(pasos);
      return _retroceder(pasos);
    };
  }

  void desinstalar() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.navigation, null);
    retrocesoDeHistorialParaPruebas = null;
  }

  bool _retroceder(int pasos) {
    final r = router;
    if (r == null || entradas.length <= pasos) return false;
    entradas.removeRange(entradas.length - pasos, entradas.length);
    r.routeInformationProvider.didPushRouteInformation(entradas.last);
    return true;
  }

  /// El botón atrás del navegador.
  Future<void> atras() async => _retroceder(1);
}

void main() {
  final historial = _HistorialFalso();

  setUp(() {
    reiniciarBaseDeHistorial();
    historial.instalar();
  });
  tearDown(historial.desinstalar);

  GoRouter construirRouter() {
    return GoRouter(
      initialLocation: '/eventos',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => shell,
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/eventos',
                  builder: (_, _) => const Scaffold(body: Text('lista')),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/eventos/:id/usar',
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                const Text('evento'),
                TextButton(
                  onPressed: () =>
                      abrirOVolverA(context, '/capturador/c1/usar'),
                  child: const Text('a actividad'),
                ),
                TextButton(
                  onPressed: () => volverAtras(context),
                  child: const Text('atrás'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/capturador/:id/usar',
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                const Text('actividad'),
                TextButton(
                  onPressed: () => abrirOVolverA(context, '/eventos/e1/usar'),
                  child: const Text('a evento'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  testWidgets(
    'el ping-pong evento/actividad no hace crecer el historial y un solo '
    'atrás sale del evento',
    (tester) async {
      final router = construirRouter();
      addTearDown(router.dispose);
      historial.router = router;

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      sembrarBaseDeHistorial(router);

      router.push('/eventos/e1/usar');
      await tester.pumpAndSettle();
      expect(historial.entradas.length, 2);

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('a actividad'));
        await tester.pumpAndSettle();
        expect(find.text('actividad'), findsOneWidget);
        expect(historial.entradas.length, 3);

        await tester.tap(find.text('a evento'));
        await tester.pumpAndSettle();
        expect(find.text('evento'), findsOneWidget);
        expect(
          historial.entradas.length,
          2,
          reason: 'volver a la madre tiene que consumir la entrada, no añadir '
              'otra: si no, el atrás del navegador repite la ida y vuelta',
        );
      }

      await historial.atras();
      await tester.pumpAndSettle();
      expect(
        find.text('lista'),
        findsOneWidget,
        reason: 'un solo atrás del navegador tiene que salir del evento',
      );
    },
  );

  testWidgets('el botón atrás de la app consume una entrada del historial', (
    tester,
  ) async {
    final router = construirRouter();
    addTearDown(router.dispose);
    historial.router = router;

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    sembrarBaseDeHistorial(router);

    router.push('/eventos/e1/usar');
    await tester.pumpAndSettle();
    expect(historial.entradas.length, 2);

    await tester.tap(find.text('atrás'));
    await tester.pumpAndSettle();

    expect(find.text('lista'), findsOneWidget);
    expect(historial.entradas.length, 1);
    expect(historial.saltos, [1]);
  });

  testWidgets(
    'tras recargar dentro de la pila el atrás no toca el historial',
    (tester) async {
      final router = construirRouter();
      addTearDown(router.dispose);
      historial.router = router;

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      router.push('/eventos/e1/usar');
      await tester.pumpAndSettle();

      // Un F5 con el evento abierto: go_router restaura la pila, pero el
      // historial del navegador arranca de cero. Retroceder ahí sacaría al
      // usuario del sitio.
      sembrarBaseDeHistorial(router);
      historial.entradas.removeRange(0, historial.entradas.length - 1);

      await tester.tap(find.text('atrás'));
      await tester.pumpAndSettle();

      expect(historial.saltos, isEmpty);
      expect(find.text('lista'), findsOneWidget);
    },
  );
}
