import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/widgets/app_image_skeleton.dart';

void main() {
  testWidgets('anima mientras está montado y deja de pedir frames al salir', (
    tester,
  ) async {
    // El invariante que importa: una lista larga de fotos comparte un solo
    // ticker, y sin esqueletos vivos no se pide ni un frame de más.
    expect(SchedulerBinding.instance.transientCallbackCount, 0);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 80, height: 80, child: AppImageSkeleton()),
        ),
      ),
    );

    expect(
      SchedulerBinding.instance.transientCallbackCount,
      1,
      reason: 'un esqueleto montado mantiene el ticker corriendo',
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox(width: 80, height: 80))),
    );

    expect(
      SchedulerBinding.instance.transientCallbackCount,
      0,
      reason: 'sin esqueletos el ticker se detiene',
    );
  });

  testWidgets('varios esqueletos comparten un único ticker', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(width: 40, height: 40, child: AppImageSkeleton()),
              SizedBox(width: 40, height: 40, child: AppImageSkeleton()),
              SizedBox(width: 40, height: 40, child: AppImageSkeleton()),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(AppImageSkeleton), findsNWidgets(3));
    expect(SchedulerBinding.instance.transientCallbackCount, 1);

    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
  });
}
