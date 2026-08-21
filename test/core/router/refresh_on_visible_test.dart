import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:transworld_nexus/core/router/refresh_on_visible.dart';
import 'package:transworld_nexus/core/router/route_paths.dart';

void main() {
  group('justBecameVisible', () {
    test('dispara al abrir la ruta por primera vez', () {
      expect(
        justBecameVisible(
          wasVisible: false,
          currentLocation: '/eventos/e1/registrados',
          targetLocation: '/eventos/e1/registrados',
        ),
        isTrue,
      );
    });

    test('no dispara si la ruta ya estaba visible', () {
      expect(
        justBecameVisible(
          wasVisible: true,
          currentLocation: '/eventos/e1/registrados',
          targetLocation: '/eventos/e1/registrados',
        ),
        isFalse,
      );
    });

    test('no dispara al abrir el evento en vez de la lista', () {
      expect(
        justBecameVisible(
          wasVisible: false,
          currentLocation: '/eventos/e1/usar',
          targetLocation: '/eventos/e1/registrados',
        ),
        isFalse,
      );
    });

    test('dispara al volver de editar a la lista', () {
      expect(
        justBecameVisible(
          wasVisible: false,
          currentLocation: '/eventos/e1/registrados',
          targetLocation: '/eventos/e1/registrados',
        ),
        isTrue,
      );
    });

    test('sin router trata la primera aparición como visible', () {
      expect(
        justBecameVisible(
          wasVisible: false,
          currentLocation: null,
          targetLocation: '/eventos',
        ),
        isTrue,
      );
    });
  });

  testWidgets('RefreshOnVisible recarga al abrir la lista y al volver a ella', (
    tester,
  ) async {
    var refrescos = 0;

    final router = GoRouter(
      initialLocation: '/hub',
      routes: [
        GoRoute(
          path: '/hub',
          builder: (_, _) => const Scaffold(body: Text('hub')),
        ),
        GoRoute(
          path: '/lista',
          builder: (_, _) => _ListaStub(onRefresh: () => refrescos++),
        ),
        GoRoute(
          path: '/detalle',
          builder: (_, _) => const Scaffold(body: Text('detalle')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    expect(refrescos, 0);

    router.go('/lista');
    await tester.pumpAndSettle();
    expect(refrescos, 1);

    router.go('/detalle');
    await tester.pumpAndSettle();
    expect(refrescos, 1);

    router.go('/lista');
    await tester.pumpAndSettle();
    expect(refrescos, 2);
  });

  testWidgets('RefreshOnVisible recarga al volver con pop, no solo con go', (
    tester,
  ) async {
    // Regresión: `GoRouteInformationProvider` notifica en `push` pero no en
    // `pop` (asigna su valor sin `notifyListeners`), así que escuchando solo
    // ese provider volver atrás nunca disparaba [onBecomeVisible]. El menú de
    // evento se quedaba con el tile de la lista girando y sin poder reabrirla.
    var refrescos = 0;

    final router = GoRouter(
      initialLocation: '/lista',
      routes: [
        GoRoute(
          path: '/lista',
          builder: (_, _) => _ListaStub(onRefresh: () => refrescos++),
        ),
        GoRoute(
          path: '/detalle',
          builder: (_, _) => const Scaffold(body: Text('detalle')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    expect(refrescos, 1);

    router.push('/detalle');
    await tester.pumpAndSettle();
    expect(find.text('detalle'), findsOneWidget);
    expect(refrescos, 1);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('lista'), findsOneWidget);
    expect(refrescos, 2, reason: 'volver atrás debe recargar la lista');
  });

  testWidgets('RefreshOnVisible espera a que la transición termine', (
    tester,
  ) async {
    // Invalidar en pleno slide reconstruye el árbol mientras la página se
    // mueve: es lo que se sentía como tirones en el gesto de volver de iOS.
    var refrescos = 0;

    final router = GoRouter(
      initialLocation: '/hub',
      routes: [
        GoRoute(
          path: '/hub',
          builder: (_, _) => const Scaffold(body: Text('hub')),
        ),
        GoRoute(
          path: '/lista',
          builder: (_, _) => _ListaStub(onRefresh: () => refrescos++),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    expect(refrescos, 0);

    router.push('/lista');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(
      refrescos,
      0,
      reason: 'no debe recargar con la transición todavía corriendo',
    );

    await tester.pumpAndSettle();
    expect(refrescos, 1, reason: 'al asentarse la ruta sí recarga');
  });

  test('volverALista hace pop cuando hay historial', () async {
    expect(RoutePaths.verRegistrados('e1'), '/eventos/e1/registrados');
    expect(RoutePaths.verLeads('c1'), '/capturador/c1/leads');
  });

  group('abrirOVolverA', () {
    late GoRouter router;

    setUp(() {
      router = GoRouter(
        initialLocation: '/eventos',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) => navigationShell,
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/eventos',
                    builder: (_, _) =>
                        const Scaffold(body: Text('lista eventos')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/capturador',
                    builder: (_, _) =>
                        const Scaffold(body: Text('lista capturador')),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/eventos/:id/usar',
            builder: (context, state) => Scaffold(
              body: Column(
                children: [
                  const Text('evento'),
                  TextButton(
                    onPressed: () =>
                        abrirOVolverA(context, '/capturador/c1/usar'),
                    child: const Text('a actividad'),
                  ),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/capturador/:id/usar',
            builder: (context, state) => Scaffold(
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
    });

    tearDown(() => router.dispose());

    List<String> stackPaths() => matchedLocationsInStack(
      router.routerDelegate.currentConfiguration,
    ).map((loc) => Uri.parse(loc).path).toList();

    testWidgets(
      'ir y volver entre evento y actividad no apila pantallas repetidas',
      (tester) async {
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        router.push('/eventos/e1/usar');
        await tester.pumpAndSettle();

        await tester.tap(find.text('a actividad'));
        await tester.pumpAndSettle();
        expect(find.text('actividad'), findsOneWidget);

        await tester.tap(find.text('a evento'));
        await tester.pumpAndSettle();
        expect(find.text('evento'), findsOneWidget);

        await tester.tap(find.text('a actividad'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('a evento'));
        await tester.pumpAndSettle();

        expect(stackPaths(), ['/eventos', '/eventos/e1/usar']);
        expect(find.text('evento'), findsOneWidget);

        router.pop();
        await tester.pumpAndSettle();
        expect(find.text('lista eventos'), findsOneWidget);
        expect(find.text('evento'), findsNothing);
        expect(find.text('actividad'), findsNothing);
      },
    );

    testWidgets(
      'desde la actividad, el evento que no está en la pila sí se empuja',
      (tester) async {
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        router.go('/capturador');
        await tester.pumpAndSettle();
        router.push('/capturador/c1/usar');
        await tester.pumpAndSettle();

        await tester.tap(find.text('a evento'));
        await tester.pumpAndSettle();
        expect(find.text('evento'), findsOneWidget);
        expect(stackPaths(), [
          '/capturador',
          '/capturador/c1/usar',
          '/eventos/e1/usar',
        ]);

        await tester.tap(find.text('a actividad'));
        await tester.pumpAndSettle();
        expect(find.text('actividad'), findsOneWidget);
        expect(stackPaths(), ['/capturador', '/capturador/c1/usar']);
      },
    );
  });

  group('pushYEsperarSalida', () {
    late GoRouter router;

    setUp(() {
      router = GoRouter(
        initialLocation: '/eventos',
        routes: [
          GoRoute(
            path: '/eventos',
            builder: (_, _) => const Scaffold(body: Text('lista')),
          ),
          GoRoute(
            path: '/eventos/:id/registrados',
            builder: (_, _) => const Scaffold(body: Text('registrados')),
          ),
        ],
      );
    });

    tearDown(() => router.dispose());

    testWidgets('resuelve con el pop normal del Navigator', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      final context = tester.element(find.text('lista'));

      var resuelto = false;
      unawaited(
        pushYEsperarSalida(
          context,
          '/eventos/e1/registrados',
        ).then((_) => resuelto = true),
      );
      await tester.pumpAndSettle();
      expect(find.text('registrados'), findsOneWidget);
      expect(resuelto, isFalse);

      router.pop();
      await tester.pumpAndSettle();
      expect(resuelto, isTrue);
    });

    testWidgets(
      'resuelve cuando la ruta sale de la pila sin pop (atrás del navegador)',
      (tester) async {
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        final context = tester.element(find.text('lista'));

        var resuelto = false;
        unawaited(
          pushYEsperarSalida(
            context,
            '/eventos/e1/registrados',
          ).then((_) => resuelto = true),
        );
        await tester.pumpAndSettle();
        expect(resuelto, isFalse);

        // El atrás del navegador no hace pop: reemplaza el `RouteMatchList`
        // completo, y go_router deja huérfano el `Completer` del push. Un `go`
        // recorre exactamente ese camino (`NavigatingType.go`).
        router.go('/eventos');
        await tester.pumpAndSettle();

        expect(find.text('lista'), findsOneWidget);
        expect(
          resuelto,
          isTrue,
          reason: 'el futuro del push queda huérfano y el spinner no se apaga',
        );
      },
    );
  });

  group('volverAtras', () {
    late GoRouter router;
    final reemplazos = <bool>[];

    setUp(() {
      reemplazos.clear();
      TestDefaultBinaryMessengerBinding
          .instance
          .defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.navigation, (call) async {
            if (call.method == 'routeInformationUpdated') {
              final args = call.arguments as Map<Object?, Object?>;
              reemplazos.add(args['replace'] as bool);
            }
            return null;
          });

      router = GoRouter(
        initialLocation: '/eventos',
        routes: [
          GoRoute(
            path: '/eventos',
            builder: (_, _) => const Scaffold(body: Text('lista')),
          ),
          GoRoute(
            path: '/eventos/:id/usar',
            builder: (context, _) => Scaffold(
              body: Column(
                children: [
                  const Text('evento'),
                  TextButton(
                    onPressed: () => volverAtras(context),
                    child: const Text('atrás'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.navigation, null);
      router.dispose();
    });

    testWidgets('vuelve sin añadir una entrada nueva al historial', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.push('/eventos/e1/usar');
      await tester.pumpAndSettle();
      expect(find.text('evento'), findsOneWidget);

      reemplazos.clear();
      await tester.tap(find.text('atrás'));
      await tester.pumpAndSettle();

      expect(find.text('lista'), findsOneWidget);
      expect(
        reemplazos,
        isNotEmpty,
        reason: 'el pop tiene que reportar la ruta al motor',
      );
      expect(
        reemplazos,
        everyElement(isTrue),
        reason: 'sin replace, el atrás de la app apila historial en web',
      );
    });

    testWidgets('en la raíz no hace nada', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      final context = tester.element(find.text('lista'));

      volverAtras(context);
      await tester.pumpAndSettle();

      expect(find.text('lista'), findsOneWidget);
    });
  });
}

class _ListaStub extends ConsumerStatefulWidget {
  const _ListaStub({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  ConsumerState<_ListaStub> createState() => _ListaStubState();
}

class _ListaStubState extends ConsumerState<_ListaStub> with RefreshOnVisible {
  @override
  String get refreshWhenLocation => '/lista';

  @override
  void onBecomeVisible() => widget.onRefresh();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('lista'));
}
