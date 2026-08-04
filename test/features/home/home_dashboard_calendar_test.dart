import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:transworld_nexus/features/home/providers/home_dashboard_providers.dart';
import 'package:transworld_nexus/features/home/widgets/home_dashboard_section.dart';

int _semanasDelMes(DateTime mes) {
  final primerDia = DateTime(mes.year, mes.month);
  final dias = DateTime(mes.year, mes.month + 1, 0).day;
  return ((primerDia.weekday - 1 + dias) / 7).ceil();
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('el calendario ajusta su altura a las semanas del mes', (
    tester,
  ) async {
    final mesInicial = DateTime(DateTime.now().year, DateTime.now().month);
    final semanasIniciales = _semanasDelMes(mesInicial);
    var saltos = 1;
    while (_semanasDelMes(
          DateTime(mesInicial.year, mesInicial.month + saltos),
        ) ==
        semanasIniciales) {
      saltos++;
    }
    final semanasFinales = _semanasDelMes(
      DateTime(mesInicial.year, mesInicial.month + saltos),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeDashboardProvider.overrideWith(
            (ref) async => const HomeDashboardData(
              eventos: [],
              totalRegistrados: 0,
              totalAcreditados: 0,
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: HomeDashboardSection(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final detalle = find.textContaining('Eventos del ');
    final posicionInicial = tester.getTopLeft(detalle).dy;

    for (var i = 0; i < saltos; i++) {
      await tester.tap(find.byIcon(Symbols.chevron_right_rounded));
      await tester.pumpAndSettle();
    }

    final posicionFinal = tester.getTopLeft(detalle).dy;
    expect(tester.takeException(), isNull);
    if (semanasFinales > semanasIniciales) {
      expect(posicionFinal, greaterThan(posicionInicial + 20));
    } else {
      expect(posicionFinal, lessThan(posicionInicial - 20));
    }
  });
}
