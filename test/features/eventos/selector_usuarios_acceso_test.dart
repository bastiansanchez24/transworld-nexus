import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/constants/app_role.dart';
import 'package:transworld_nexus/data/models/perfil.dart';
import 'package:transworld_nexus/features/eventos/widgets/selector_usuarios_acceso.dart';

Perfil _perfil(String id, String nombre, AppRole rol, {bool activo = true}) {
  return Perfil(
    id: id,
    nombreCompleto: nombre,
    rol: rol,
    activo: activo,
  );
}

void main() {
  testWidgets('lista usuarios asignables sin chips', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectorUsuariosAcceso(
            usuarios: [
              _perfil('u1', 'Ana User', AppRole.user),
              _perfil('u2', 'Bruno Externo', AppRole.externo),
            ],
            seleccionados: const {'u1'},
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Ana User'), findsOneWidget);
    expect(find.text('Bruno Externo'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);
    expect(find.text('1 usuario con acceso.'), findsOneWidget);
  });

  testWidgets('no permite agregar externos a un evento no operable', (
    tester,
  ) async {
    var seleccionados = <String>{};

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SelectorUsuariosAcceso(
                usuarios: [_perfil('u2', 'Bruno Externo', AppRole.externo)],
                seleccionados: seleccionados,
                permiteNuevosExternos: false,
                onChanged: (ids) => setState(() => seleccionados = ids),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Solo eventos activos'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(find.textContaining('con acceso'), findsNothing);
  });
}
