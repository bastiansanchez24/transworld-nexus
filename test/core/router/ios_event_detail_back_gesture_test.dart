import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:transworld_nexus/core/router/page_transitions.dart';
import 'package:transworld_nexus/core/router/refresh_on_visible.dart';
import 'package:transworld_nexus/core/widgets/ios_back_swipe_committer.dart';

void main() {
  testWidgets('detalle de evento confirma un swipe mayor a la mitad', (
    tester,
  ) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = previousPlatform);

    final router = GoRouter(
      initialLocation: '/eventos',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              PopScope(canPop: false, child: Scaffold(body: shell)),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/eventos',
                  builder: (context, state) => const _ListaEventos(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/eventos/:id/usar',
          pageBuilder: (context, state) =>
              sharedAxisPage(key: state.pageKey, child: const _DetalleEvento()),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    router.push('/eventos/1/usar');
    await tester.pumpAndSettle();

    expect(find.text('Detalle del evento'), findsOneWidget);
    final size = tester.getSize(find.byType(MaterialApp));
    final gesture = await tester.startGesture(Offset(1, size.height / 2));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.moveBy(Offset(size.width * 1.2, 0));
    // Simula soltar después de desacelerar con movimiento inverso.
    // Cupertino prioriza esa velocidad final aunque la página ya cruzó 50%.
    await tester.pump(const Duration(milliseconds: 200));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 5));
      await gesture.moveBy(Offset(-size.width * 0.15, 0));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/eventos');
    expect(find.text('Lista de eventos'), findsOneWidget);
    expect(find.text('Detalle del evento'), findsNothing);

    debugDefaultTargetPlatformOverride = previousPlatform;
  });
}

class _ListaEventos extends ConsumerStatefulWidget {
  const _ListaEventos();

  @override
  ConsumerState<_ListaEventos> createState() => _ListaEventosState();
}

class _ListaEventosState extends ConsumerState<_ListaEventos>
    with RefreshOnVisible {
  @override
  String get refreshWhenLocation => '/eventos';

  @override
  void onBecomeVisible() {}

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Lista de eventos'));
  }
}

class _DetalleEvento extends ConsumerStatefulWidget {
  const _DetalleEvento();

  @override
  ConsumerState<_DetalleEvento> createState() => _DetalleEventoState();
}

class _DetalleEventoState extends ConsumerState<_DetalleEvento>
    with RefreshOnVisible {
  @override
  String get refreshWhenLocation => '/eventos/1/usar';

  @override
  void onBecomeVisible() {}

  @override
  Widget build(BuildContext context) {
    return const IosBackSwipeCommitter(
      child: Scaffold(body: Center(child: Text('Detalle del evento'))),
    );
  }
}
