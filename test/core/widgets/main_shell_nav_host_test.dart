import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:transworld_nexus/core/theme/app_theme.dart';
import 'package:transworld_nexus/core/theme/tw_tokens.dart';
import 'package:transworld_nexus/core/widgets/ios_native_tab_bar.dart';
import 'package:transworld_nexus/core/widgets/main_shell_scaffold.dart';
import 'package:transworld_nexus/core/widgets/tw_bottom_nav_bar.dart';

const _items = [
  TwNavItemData(
    icon: Symbols.home_rounded,
    label: 'Inicio',
    sfSymbol: 'house',
    sfSymbolActive: 'house.fill',
  ),
  TwNavItemData(
    icon: Symbols.calendar_month_rounded,
    label: 'Eventos',
    sfSymbol: 'calendar',
    sfSymbolActive: 'calendar.fill',
  ),
  TwNavItemData(
    icon: Symbols.person_search_rounded,
    label: 'Leads',
    sfSymbol: 'person.crop.circle.badge.magnifyingglass',
  ),
];

void main() {
  testWidgets('en Android el menú queda abajo y no monta el rail', (
    tester,
  ) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MainShellNavHost(
            selectedIndex: 0,
            onItemSelected: (_) {},
            items: _items,
            body: const ColoredBox(
              color: Colors.red,
              child: SizedBox.expand(child: Text('cuerpo')),
            ),
          ),
        ),
      );

      expect(find.byType(TwBottomNavBar), findsOneWidget);
      expect(find.byType(TwSideNavRail), findsNothing);
      expect(find.byType(IosNativeTabBar), findsNothing);
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('cuerpo'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  });

  testWidgets('en Windows el menú pasa al rail izquierdo', (tester) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MainShellNavHost(
            selectedIndex: 1,
            onItemSelected: (_) {},
            items: _items,
            body: const ColoredBox(
              color: Colors.red,
              child: SizedBox.expand(child: Text('cuerpo')),
            ),
          ),
        ),
      );

      expect(find.byType(TwSideNavRail), findsOneWidget);
      expect(find.byType(TwBottomNavBar), findsNothing);
      expect(find.byType(IosNativeTabBar), findsNothing);
      expect(
        tester.getSize(find.byType(TwSideNavRail)).width,
        GlassNavTokens.sideRailWidth,
      );

      final rail = tester.getRect(find.byType(TwSideNavRail));
      final body = tester.getRect(find.text('cuerpo'));
      expect(rail.left, 0);
      expect(body.left, greaterThanOrEqualTo(rail.right));

      final railMaterial = tester.widget<Material>(
        find.descendant(
          of: find.byType(TwSideNavRail),
          matching: find.byType(Material),
        ),
      );
      expect(railMaterial.color, TwColors.bg);
      expect(find.byType(Divider), findsNWidgets(_items.length - 1));

      final inicio = tester.getRect(find.text('Inicio'));
      final eventos = tester.getRect(find.text('Eventos'));
      expect(
        eventos.top - inicio.bottom,
        greaterThan(GlassNavTokens.sideRailSeparatorHeight),
      );
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  });

  testWidgets('en macOS nativo el menú sigue abajo', (tester) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MainShellNavHost(
            selectedIndex: 0,
            onItemSelected: (_) {},
            items: _items,
            body: const ColoredBox(
              color: Colors.red,
              child: SizedBox.expand(child: Text('cuerpo')),
            ),
          ),
        ),
      );

      expect(find.byType(TwBottomNavBar), findsOneWidget);
      expect(find.byType(TwSideNavRail), findsNothing);
      expect(find.byType(IosNativeTabBar), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  });

  testWidgets('el rail reporta el ítem pulsado', (tester) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    var selected = 0;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MainShellNavHost(
            selectedIndex: 0,
            onItemSelected: (index) => selected = index,
            items: _items,
            body: const SizedBox.expand(),
          ),
        ),
      );

      await tester.tap(find.text('Leads'));
      expect(selected, 2);
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  });

  testWidgets('en iOS el menú es la tab bar nativa, no el pill Flutter', (
    tester,
  ) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MainShellNavHost(
            selectedIndex: 0,
            onItemSelected: (_) {},
            items: _items,
            body: const ColoredBox(
              color: Colors.red,
              child: SizedBox.expand(child: Text('cuerpo')),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(IosNativeTabBar), findsOneWidget);
      expect(find.byType(TwBottomNavBar), findsNothing);
      expect(find.byType(TwSideNavRail), findsNothing);
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('cuerpo'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  });

  testWidgets('en iOS la tab bar reporta el ítem pulsado', (tester) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var selected = 0;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MainShellNavHost(
            selectedIndex: 0,
            onItemSelected: (index) => selected = index,
            items: _items,
            body: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Leads'));
      expect(selected, 2);
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  });
}
