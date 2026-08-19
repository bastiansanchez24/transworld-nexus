import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transworld_nexus/core/network/connectivity_service.dart';
import 'package:transworld_nexus/core/widgets/app_scaffold.dart';
import 'package:transworld_nexus/core/widgets/offline_banner.dart';
import 'package:transworld_nexus/data/offline/sync_queue_service.dart';

/// Alto de la barra de estado simulada.
const double _altoBarraEstado = 44;

const String _titulo = 'Editar algo';

/// Monta una pantalla push con una barra de estado real y el estado de red
/// indicado.
Future<void> _montar(WidgetTester tester, {required bool hayRed}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = const FakeViewPadding(top: _altoBarraEstado);
  addTearDown(tester.view.reset);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const AppScaffold(title: _titulo, body: SizedBox.shrink()),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        connectivityStreamProvider.overrideWith((ref) => Stream.value(hayRed)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

/// Distancia entre el borde superior de la cabecera y su título. Es lo que
/// crece cuando la cabecera reserva la barra de estado.
double _huecoSobreElTitulo(WidgetTester tester, {required double topCabecera}) {
  return tester.getRect(find.text(_titulo)).top - topCabecera;
}

void main() {
  testWidgets('con red el banner no ocupa sitio', (tester) async {
    await _montar(tester, hayRed: true);
    expect(find.text('Sin conexión'), findsNothing);
  });

  testWidgets('sin red el aviso se pinta debajo de la hora', (tester) async {
    await _montar(tester, hayRed: false);

    final texto = find.text('Sin conexión');
    expect(texto, findsOneWidget);

    // El banner arranca en el borde superior —pinta el fondo tras el reloj—
    // pero su contenido empieza por debajo de la barra de estado.
    final banner = tester.getRect(find.byType(OfflineBanner));
    expect(banner.top, 0);
    expect(
      tester.getRect(texto).top,
      greaterThanOrEqualTo(_altoBarraEstado),
      reason: 'el texto quedaría tapado por la hora del sistema',
    );
  });

  testWidgets('la cabecera arranca justo bajo el banner', (tester) async {
    await _montar(tester, hayRed: false);

    final banner = tester.getRect(find.byType(OfflineBanner));
    expect(
      _huecoSobreElTitulo(tester, topCabecera: banner.bottom),
      greaterThan(0),
      reason: 'la cabecera debe quedar por debajo del banner, no detrás',
    );
  });

  group('la barra de estado se reserva una sola vez', () {
    /// Monta el host y devuelve el `padding` que ve el contenido de abajo.
    Future<EdgeInsets> paddingBajoElBanner(
      WidgetTester tester, {
      required bool hayRed,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      late EdgeInsets visto;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            connectivityStreamProvider.overrideWith(
              (ref) => Stream.value(hayRed),
            ),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                padding: EdgeInsets.only(top: _altoBarraEstado),
              ),
              child: Scaffold(
                body: OfflineBannerHost(
                  builder: (context) {
                    visto = MediaQuery.paddingOf(context);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return visto;
    }

    testWidgets('con banner el contenido de abajo ya no la reserva', (
      tester,
    ) async {
      // El banner se queda con el inset; si la cabecera de abajo también lo
      // reservara, quedaría bajo el aviso un hueco muerto del alto de la barra.
      expect((await paddingBajoElBanner(tester, hayRed: false)).top, 0);
    });

    testWidgets('sin banner la pantalla la reserva como siempre', (
      tester,
    ) async {
      expect(
        (await paddingBajoElBanner(tester, hayRed: true)).top,
        _altoBarraEstado,
      );
    });
  });
}
