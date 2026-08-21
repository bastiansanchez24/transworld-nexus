import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:transworld_nexus/core/theme/app_scroll_behavior.dart';
import 'package:transworld_nexus/core/widgets/windows_mouse_gestures.dart';

void main() {
  test('el mouse arrastra en el ScrollBehavior', () {
    expect(
      const AppScrollBehavior().dragDevices,
      containsAll({
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.touch,
      }),
    );
  });

  test('los gestos de mouse son de Windows nativo', () {
    expect(
      windowsOwnsMouseGestures(isWeb: false, platform: TargetPlatform.windows),
      isTrue,
    );
    expect(
      windowsOwnsMouseGestures(isWeb: true, platform: TargetPlatform.windows),
      isFalse,
    );
    expect(
      windowsOwnsMouseGestures(isWeb: false, platform: TargetPlatform.android),
      isFalse,
    );
  });

  testWidgets('arrastrar desde el borde no se interpreta como atrás', (
    tester,
  ) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(_appConHistorial());
      expect(find.text('detalle'), findsOneWidget);

      await tester.dragFrom(const Offset(8, 200), const Offset(160, 0));
      await tester.pumpAndSettle();

      expect(find.text('detalle'), findsOneWidget);
      expect(find.text('lista'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  });

  testWidgets('el botón atrás del mouse vuelve atrás', (tester) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(_appConHistorial());
      expect(find.text('detalle'), findsOneWidget);

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kBackMouseButton,
      );
      await gesture.down(tester.getCenter(find.text('detalle')));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('lista'), findsOneWidget);
      expect(find.text('detalle'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  });

  test('el pop directo X1 se limita a menú y acceso de evento', () {
    expect(eventRouteUsesDirectMouseBack('/eventos/e1/usar'), isTrue);
    expect(eventRouteUsesDirectMouseBack('/eventos/e1/acceso'), isTrue);
    expect(eventRouteUsesDirectMouseBack('/eventos/e1/editar'), isFalse);
    expect(eventRouteUsesDirectMouseBack('/eventos'), isFalse);
    expect(eventRouteUsesDirectMouseBack('/capturador/e1/usar'), isFalse);
  });

  for (final detailPath in const ['/eventos/e1/usar', '/eventos/e1/acceso']) {
    testWidgets('X1 hace un solo pop desde $detailPath sobre el shell', (
      tester,
    ) async {
      final previous = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final router = _eventRouter(detailPath);
      addTearDown(router.dispose);
      addTearDown(() => debugDefaultTargetPlatformOverride = previous);

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => WindowsMouseGestures(
            router: router,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      router.push(detailPath);
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kBackMouseButton,
      );
      await gesture.down(tester.getCenter(find.text(detailPath)));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.path, '/eventos');
      expect(find.text('lista-eventos'), findsOneWidget);
      expect(find.text(detailPath), findsNothing);
      debugDefaultTargetPlatformOverride = previous;
    });
  }
}

GoRouter _eventRouter(String detailPath) => GoRouter(
  initialLocation: '/eventos',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) =>
          PopScope(canPop: false, child: Scaffold(body: shell)),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/eventos',
              builder: (_, _) => const Text('lista-eventos'),
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: detailPath, builder: (_, _) => Text(detailPath)),
  ],
);

Widget _appConHistorial() {
  final router = GoRouter(
    initialLocation: '/detalle',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Text('lista'),
        routes: [
          GoRoute(path: 'detalle', builder: (_, _) => const Text('detalle')),
        ],
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    scrollBehavior: const AppScrollBehavior(),
    builder: (context, child) => WindowsMouseGestures(
      router: router,
      child: child ?? const SizedBox.shrink(),
    ),
  );
}
