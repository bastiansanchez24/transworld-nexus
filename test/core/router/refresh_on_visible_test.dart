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
