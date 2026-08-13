import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/widgets/nexus_components.dart';

void main() {
  testWidgets('muestra nombre y correo sin foto', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PersonaIdentityBanner(
            nombre: 'María González',
            email: 'maria@empresa.com',
          ),
        ),
      ),
    );

    expect(find.text('María González'), findsOneWidget);
    expect(find.text('maria@empresa.com'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.byType(AvatarInitials), findsNothing);
    expect(find.byType(AvatarPerfil), findsNothing);
  });

  testWidgets('sin nombre usa el placeholder y omite el correo vacío', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PersonaIdentityBanner(nombre: '  ', email: ''),
        ),
      ),
    );

    expect(find.text('Sin nombre'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
  });

  testWidgets('con controller el nombre se edita dentro de la card', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'María González');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonaIdentityBanner(
            nombre: controller.text,
            email: 'maria@empresa.com',
            nombreController: controller,
          ),
        ),
      ),
    );

    final campo = find.descendant(
      of: find.byType(PersonaIdentityBanner),
      matching: find.byType(TextFormField),
    );
    expect(campo, findsOneWidget);

    await tester.enterText(campo, 'María Pérez');
    expect(controller.text, 'María Pérez');
  });

  testWidgets('deja aire arriba y acepta una foto a la izquierda', (
    tester,
  ) async {
    const claveFoto = Key('foto');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PersonaIdentityBanner(
            nombre: 'María González',
            email: 'maria@empresa.com',
            leading: SizedBox(key: claveFoto, width: 60, height: 60),
          ),
        ),
      ),
    );

    expect(find.byKey(claveFoto), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(claveFoto)).dx,
      lessThan(tester.getTopLeft(find.text('María González')).dx),
    );

    final margen = tester
        .widget<Container>(
          find
              .descendant(
                of: find.byType(PersonaIdentityBanner),
                matching: find.byType(Container),
              )
              .first,
        )
        .margin;
    expect(margen, const EdgeInsets.only(top: 12));
  });

  testWidgets('el validador del nombre corre con el formulario', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final formKey = GlobalKey<FormState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: PersonaIdentityBanner(
              nombre: '',
              email: '',
              nombreController: controller,
              nombreValidator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Requerido'), findsOneWidget);
  });
}
