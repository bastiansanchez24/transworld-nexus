import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/widgets/tw_toast.dart';

void main() {
  tearDown(TwToast.hide);

  testWidgets('al aparecer el toast sube; al irse solo se desvanece', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => TwToast.info(context, 'Listo'),
              child: const Text('Mostrar'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mostrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text('Listo'), findsOneWidget);
    final slide = find.byKey(const Key('tw-toast-slide'));
    final fade = find.byKey(const Key('tw-toast-fade'));
    expect(
      tester.widget<SlideTransition>(slide).position.value.dy,
      greaterThan(0),
    );

    await tester.pumpAndSettle();
    expect(tester.widget<SlideTransition>(slide).position.value.dy, 0);
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);

    TwToast.hide();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text('Listo'), findsOneWidget);
    expect(tester.widget<SlideTransition>(slide).position.value.dy, 0);
    expect(tester.widget<FadeTransition>(fade).opacity.value, lessThan(1));
  });
}
