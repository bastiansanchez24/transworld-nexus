import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/desktop/desktop_window.dart';
import 'package:transworld_nexus/core/desktop/windows_title_bar.dart';
import 'package:transworld_nexus/core/theme/app_theme.dart';

void main() {
  testWidgets('DesktopWindowFrame no monta chrome sin bootstrap', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DesktopWindowFrame(child: Text('contenido')),
      ),
    );

    expect(find.text('contenido'), findsOneWidget);
    expect(find.byType(WindowsTitleBar), findsNothing);
  });

  testWidgets('la barra muestra la marca y los tres botones de ventana', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: WindowsTitleBar(),
        ),
      ),
    );

    expect(find.text('RegisPro'), findsOneWidget);
    expect(find.byType(WindowsCaptionButton), findsNWidgets(3));
    expect(
      tester.getSize(find.byType(WindowsTitleBar)),
      const Size(800, WindowsTitleBar.height),
    );
    expect(
      tester
          .widgetList<Material>(find.byType(Material))
          .any((m) => m.color == AppColors.primaryDeep),
      isTrue,
    );
  });

  testWidgets('los botones disparan minimizar, maximizar y cerrar', (
    tester,
  ) async {
    var minimize = 0;
    var maximize = 0;
    var close = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: WindowsTitleBar(
            onMinimize: () => minimize++,
            onToggleMaximize: () => maximize++,
            onClose: () => close++,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Minimizar'));
    await tester.tap(find.byTooltip('Maximizar'));
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pump();

    expect(minimize, 1);
    expect(maximize, 1);
    expect(close, 1);
  });

  testWidgets('maximizada muestra Restaurar en lugar de Maximizar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: WindowsTitleBar(isMaximized: true),
        ),
      ),
    );

    expect(find.byTooltip('Restaurar'), findsOneWidget);
    expect(find.byTooltip('Maximizar'), findsNothing);
  });
}
