import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:transworld_nexus/core/widgets/tw_components.dart';

void main() {
  testWidgets('con loading el tile muestra spinner en vez del chevron', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwActionTile(
            icon: Symbols.contacts_rounded,
            title: 'Ver leads',
            loading: true,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Symbols.chevron_right_rounded), findsNothing);
  });
}
