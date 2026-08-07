import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/widgets/app_widgets.dart';

void main() {
  testWidgets('la confirmación destructiva exige una decisión explícita', (
    tester,
  ) async {
    bool? resultado;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                resultado = await confirmDialog(
                  context,
                  title: 'Desinstalar Nexus',
                  message: 'Esta acción no se puede deshacer.',
                  confirmLabel: 'Desinstalar',
                  destructive: true,
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.text('Desinstalar Nexus'), findsOneWidget);
    expect(find.text('Esta acción no se puede deshacer.'), findsOneWidget);
    expect(resultado, isNull);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('Desinstalar Nexus'), findsOneWidget);
    expect(resultado, isNull);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Desinstalar Nexus'), findsNothing);
    expect(resultado, isFalse);
  });
}
