import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:transworld_nexus/core/widgets/action_lock.dart';
import 'package:transworld_nexus/core/widgets/tw_components.dart';

void main() {
  test('el segundo tryLock se ignora hasta soltar', () {
    expect(ActionLock.instance.tryLock(), isTrue);
    expect(ActionLock.instance.tryLock(), isFalse);
    ActionLock.instance.unlock();
    expect(ActionLock.instance.tryLock(), isTrue);
    ActionLock.instance.unlock();
  });

  testWidgets('dos taps rápidos a un tile abren una sola ruta', (tester) async {
    var pushes = 0;
    final router = GoRouter(
      observers: [ActionLockObserver()],
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => ActionLockBarrier(
            child: Scaffold(
              body: TwActionTile(
                icon: Symbols.contacts_rounded,
                title: 'Ver leads',
                onTap: () {
                  pushes++;
                  context.push('/leads');
                },
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/leads',
          builder: (_, _) => const Scaffold(body: Text('Leads')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver leads'));
    await tester.tap(find.text('Ver leads'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(pushes, 1);
    expect(find.text('Leads'), findsOneWidget);
  });

  testWidgets('un tap a un toggle no deja el overlay puesto', (tester) async {
    var toques = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ActionLockBarrier(
          child: Scaffold(
            body: TwPressable(
              onTap: () => toques++,
              child: const Text('Día 12'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Día 12'));
    await tester.pump();
    await tester.pump();

    expect(toques, 1);
    expect(ActionLock.instance.isLocked, isFalse);

    await tester.tap(find.text('Día 12'));
    await tester.pump();
    await tester.pump();
    expect(toques, 2);
  });
}
