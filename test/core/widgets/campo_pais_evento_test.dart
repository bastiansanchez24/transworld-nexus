import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/constants/paises_evento.dart';
import 'package:transworld_nexus/core/widgets/campo_pais_evento.dart';

void main() {
  testWidgets('preselecciona Chile y solo ofrece Chile y Perú', (tester) async {
    var pais = kPaisEventoChile;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => CampoPaisEvento(
              value: pais,
              onChanged: (value) => setState(() => pais = value),
            ),
          ),
        ),
      ),
    );

    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('campo_pais_evento')),
    );
    expect(dropdown.initialValue, kPaisEventoChile);

    await tester.tap(find.byKey(const Key('campo_pais_evento')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chile'), findsWidgets);
    expect(find.textContaining('Perú'), findsOneWidget);

    await tester.tap(find.textContaining('Perú'));
    await tester.pumpAndSettle();
    expect(pais, kPaisEventoPeru);
  });
}
