import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/desktop/desktop_window.dart';

void main() {
  testWidgets('DesktopWindowFrame no monta chrome sin bootstrap', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: DesktopWindowFrame(child: Text('contenido'))),
    );

    expect(find.text('contenido'), findsOneWidget);
  });

  testWidgets('el frame nativo no pinta una segunda barra de título', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: DesktopWindowFrame(child: Text('contenido'))),
    );

    expect(find.text('contenido'), findsOneWidget);
    expect(find.text('RegisPro'), findsNothing);
  });
}
