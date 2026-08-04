import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:transworld_nexus/core/widgets/evento_list_context_menu.dart';
import 'package:transworld_nexus/core/widgets/nexus_components.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es', null);
  });

  testWidgets('EventRow muestra chincheta cuando está fijado', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        home: Scaffold(
          body: EventRow(
            date: DateTime(2026, 8, 10),
            title: 'Summit 2026',
            place: 'Santiago',
            fijado: true,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Symbols.push_pin_rounded), findsOneWidget);
    expect(find.text('Summit 2026'), findsOneWidget);
  });

  testWidgets('menú contextual respeta permisos RBAC', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showEventoListContextMenu(
                    context,
                    titulo: 'Campaña demo',
                    fijado: false,
                    puedeEditar: true,
                    puedeEliminar: false,
                  );
                },
                child: const Text('Abrir'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Fijar'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Eliminar'), findsNothing);
  });
}
