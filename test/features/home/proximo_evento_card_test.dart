import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:transworld_nexus/features/home/models/home_featured_item.dart';
import 'package:transworld_nexus/features/home/widgets/proximo_evento_card.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('desliza las cards sin cambiar la altura máxima', (tester) async {
    final items = [
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
}
