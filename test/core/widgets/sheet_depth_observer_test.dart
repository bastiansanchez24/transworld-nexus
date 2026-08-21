import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/widgets/sheet_depth_observer.dart';

void main() {
  setUp(SheetDepthObserver.reiniciarParaTest);

  Future<void> montar(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [SheetDepthObserver()],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const SizedBox(height: 120),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('cuenta la hoja mientras está presentada', (tester) async {
    await montar(tester);
    expect(SheetDepthObserver.depth.value, 0);

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(SheetDepthObserver.depth.value, 1);
  });

  testWidgets('no baja hasta que la hoja terminó de irse', (tester) async {
    // Es el arreglo del parpadeo: el contador del paquete baja en t=0 de la
    // animación de cierre y el `UITabBar` se recreaba con la hoja aún en
    // pantalla.
    await montar(tester);
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(SheetDepthObserver.depth.value, 1);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      SheetDepthObserver.depth.value,
      1,
      reason: 'la hoja todavía está bajando',
    );

    await tester.pumpAndSettle();
    expect(SheetDepthObserver.depth.value, 0);
  });

  testWidgets('un diálogo no cuenta como hoja', (tester) async {
    // Los popups pequeños no tapan la tab bar: esconderla se vería como un
    // salto y no arregla nada.
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [SheetDepthObserver()],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const AlertDialog(title: Text('hola')),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(SheetDepthObserver.depth.value, 0);
  });
}
