import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:transworld_nexus/features/home/models/home_featured_item.dart';
import 'package:transworld_nexus/features/home/widgets/proximo_evento_card.dart';

final _items = [
  HomeFeaturedItem(
    kind: HomeFeaturedKind.eventoFijado,
    id: 'evento-1',
    nombre: 'Evento destacado con un nombre suficientemente extenso',
    fecha: DateTime(2026, 8, 10),
    lugar: 'Santiago de Chile',
  ),
  HomeFeaturedItem(
    kind: HomeFeaturedKind.campanaFijada,
    id: 'campana-1',
    nombre: 'Campaña destacada',
    fecha: DateTime(2026, 9, 12),
  ),
];

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('desliza las cards sin cambiar la altura máxima', (tester) async {
    final items = _items;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.6),
            ),
            child: Center(
              child: SizedBox(
                width: 320,
                child: ProximoEventoCard(items: items),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(AnimatedSwitcher), findsNothing);
    final alturaInicial = tester.getSize(find.byType(ProximoEventoCard)).height;
    expect(alturaInicial, greaterThan(96));

    await tester.fling(
      find.text('Evento destacado con un nombre suficientemente extenso'),
      const Offset(-250, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('Campaña destacada'), findsOneWidget);
    expect(
      tester.getSize(find.byType(ProximoEventoCard)).height,
      alturaInicial,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('en móvil no aparecen flechas: basta el swipe', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 320, child: ProximoEventoCard(items: _items)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('proximo_evento_siguiente')), findsNothing);
    expect(find.byKey(const Key('proximo_evento_anterior')), findsNothing);
  });

  testWidgets('en Windows las flechas cambian de card', (tester) async {
    // El binding exige devolver la variable de debug antes de terminar el
    // cuerpo del test, así que no sirve un addTearDown.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 420,
                child: ProximoEventoCard(items: _items),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final siguiente = find.byKey(const Key('proximo_evento_siguiente'));
      expect(siguiente, findsOneWidget);
      expect(find.text('Campaña destacada'), findsNothing);

      await tester.tap(siguiente);
      await tester.pumpAndSettle();
      expect(find.text('Campaña destacada'), findsOneWidget);

      await tester.tap(find.byKey(const Key('proximo_evento_anterior')));
      await tester.pumpAndSettle();
      expect(
        find.text('Evento destacado con un nombre suficientemente extenso'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
