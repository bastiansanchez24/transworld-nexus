import 'package:flutter/material.dart';
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
