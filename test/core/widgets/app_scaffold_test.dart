import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transworld_nexus/core/network/connectivity_service.dart';
import 'package:transworld_nexus/core/theme/tw_tokens.dart';
import 'package:transworld_nexus/core/widgets/app_scaffold.dart';
import 'package:transworld_nexus/data/offline/sync_queue_service.dart';

/// Monta una pantalla push como las de edición. La ruta es hija de `/` para
/// que `context.canPop()` sea true y se dibuje el botón "atrás".
Future<void> _montarPantallaPush(
  WidgetTester tester, {
  List<Widget>? actions,
  Widget body = const SizedBox.shrink(),
  bool settle = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final router = GoRouter(
    initialLocation: '/editar',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const SizedBox.shrink(),
        routes: [
          GoRoute(
            path: 'editar',
            builder: (_, _) =>
                AppScaffold(title: 'Editar algo', actions: actions, body: body),
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  // Un spinner nunca "asienta": con `loading` hay que quedarse en pump().
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Alto de la cabecera: el `BackdropFilter` envuelve exactamente la barra.
double _altoCabecera(WidgetTester tester) =>
    tester.getSize(find.byType(BackdropFilter).first).height;

void main() {
  testWidgets('el botón atrás y la acción son el mismo chip', (tester) async {
    await _montarPantallaPush(
      tester,
      actions: [
        NexusHeaderAction(icon: Symbols.delete_outline_rounded, onTap: () {}),
      ],
    );

    final chips = find.byType(NexusHeaderAction);
    expect(chips, findsNWidgets(2));

    // Mismo tamaño a ambos lados.
    for (var i = 0; i < 2; i++) {
      expect(
        tester.getSize(chips.at(i)),
        const Size(NexusHeaderAction.size, NexusHeaderAction.size),
      );
    }

    // Y el mismo tratamiento visual: fondo, radio y borde.
    final decoraciones = tester
        .widgetList<Container>(
          find.descendant(of: chips, matching: find.byType(Container)),
        )
        .map((c) => c.decoration)
        .toList();
    expect(decoraciones, hasLength(2));
    expect(decoraciones.first, decoraciones.last);
    expect((decoraciones.first! as BoxDecoration).border, isNotNull);
  });

  // Antes la acción era un `IconButton`, que impone su minHeight de 48 dentro
  // de un slot de 36: la barra medía distinto según hubiera botón eliminar.
  testWidgets('la cabecera mide igual con y sin acción', (tester) async {
    await _montarPantallaPush(tester);
    final sinAccion = _altoCabecera(tester);

    await _montarPantallaPush(
      tester,
      actions: [
        NexusHeaderAction(icon: Symbols.delete_outline_rounded, onTap: () {}),
      ],
    );

    expect(_altoCabecera(tester), sinAccion);
  });

  testWidgets('una acción deshabilitada se ve atenuada', (tester) async {
    await _montarPantallaPush(
      tester,
      actions: const [NexusHeaderAction(icon: Symbols.delete_outline_rounded)],
    );

    final icono = tester.widget<Icon>(
      find.byIcon(Symbols.delete_outline_rounded),
    );
    expect(icono.color, TwColors.muted);
  });

  testWidgets('una acción activa usa el color de peligro', (tester) async {
    await _montarPantallaPush(
      tester,
      actions: [
        NexusHeaderAction(
          icon: Symbols.delete_outline_rounded,
          danger: true,
          onTap: () {},
        ),
      ],
    );

    final icono = tester.widget<Icon>(
      find.byIcon(Symbols.delete_outline_rounded),
    );
    expect(icono.color, TwColors.danger);
  });

  testWidgets('en estado loading muestra el spinner en lugar del icono', (
    tester,
  ) async {
    await _montarPantallaPush(
      tester,
      settle: false,
      actions: [
        NexusHeaderAction(
          icon: Symbols.delete_outline_rounded,
          loading: true,
          onTap: () {},
        ),
      ],
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Symbols.delete_outline_rounded), findsNothing);
    // El chip no cambia de tamaño al pasar a loading.
    expect(
      tester.getSize(find.byType(NexusHeaderAction).last),
      const Size(NexusHeaderAction.size, NexusHeaderAction.size),
    );
  });

  testWidgets('un cuerpo corto arranca bajo la cabecera, no al centro', (
    tester,
  ) async {
    const cuerpo = Key('cuerpo-corto');
    await _montarPantallaPush(
      tester,
      body: const ColoredBox(
        key: cuerpo,
        color: Color(0xFFFF0000),
        child: SizedBox(height: 48, width: 200),
      ),
    );

    final headerBottom = tester
        .getRect(find.byType(BackdropFilter).first)
        .bottom;
    final bodyTop = tester.getRect(find.byKey(cuerpo)).top;
    expect(bodyTop, closeTo(headerBottom, 0.5));
  });
}
