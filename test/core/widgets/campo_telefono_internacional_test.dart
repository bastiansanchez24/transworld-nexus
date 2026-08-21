import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/utils/registro_asistente.dart';
import 'package:transworld_nexus/core/widgets/campos_registro_asistente.dart';

void main() {
  testWidgets('Chile conserva únicamente los nueve dígitos nacionales', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            child: CampoTelefonoInternacional(
              controller: controller,
              pais: kPaisTelefonoChile,
              onPaisChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('+56'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '+56 9 1234 5678');
    expect(controller.text, '912345678');

    await tester.enterText(find.byType(TextFormField), '9123456780');
    expect(controller.text, '912345678');
  });

  testWidgets('el modo opcional valida solo cuando hay un número', (
    tester,
  ) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: CampoTelefonoInternacional(
              controller: controller,
              pais: kPaisTelefonoPeru,
              onPaisChanged: (_) {},
              requerido: false,
            ),
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), isTrue);
    await tester.enterText(find.byType(TextFormField), '123');
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Ingresa 9 dígitos'), findsOneWidget);
  });
}
