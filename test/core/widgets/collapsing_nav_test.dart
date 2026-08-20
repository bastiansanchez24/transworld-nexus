import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:transworld_nexus/core/theme/tw_tokens.dart';
import 'package:transworld_nexus/core/widgets/collapsing_nav.dart';
import 'package:transworld_nexus/core/widgets/tw_components.dart';
import 'package:transworld_nexus/core/widgets/tw_detail_scaffold.dart';

void _noop() {}

void main() {
  Future<void> montarLista(WidgetTester tester, {required EdgeInsets padding}) {
    return tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: const Size(1200, 800), padding: padding),
          child: CollapsingScrollScaffold(
            title: 'Registrados',
            alwaysShowActions: true,
            overlayLeading: CollapsingNavButton(
              icon: Symbols.arrow_back_ios_new_rounded,
              onTap: () {},
            ),
            slivers: const [SliverToBoxAdapter(child: SizedBox(height: 1200))],
          ),
        ),
      ),
    );
  }

  testWidgets('sin safe area (web y Windows) el atrás no toca el borde', (
    tester,
  ) async {
    await montarLista(tester, padding: EdgeInsets.zero);
    await tester.pumpAndSettle();

    final boton = find.byType(CollapsingNavButton);
    expect(boton, findsOneWidget);
    expect(
      tester.getTopLeft(boton).dy,
      greaterThanOrEqualTo(CollapsingNavMetrics.gapTop),
    );
  });

  testWidgets('con notch el atrás baja además del inset del sistema', (
    tester,
  ) async {
    await montarLista(tester, padding: const EdgeInsets.only(top: 47));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byType(CollapsingNavButton)).dy,
      greaterThanOrEqualTo(47 + CollapsingNavMetrics.gapTop),
    );
  });

  testWidgets('el atrás de la lista alinea con el menú de acciones', (
    tester,
  ) async {
    await montarLista(tester, padding: EdgeInsets.zero);
    await tester.pumpAndSettle();

    final boton = tester.getRect(find.byType(TwIconButton).first);
    expect(boton.left, TwSpacing.screenH);
    expect(boton.top, TwDetailBarMetrics.gapVertical);
  });

  testWidgets('el menú de acciones no salta si el gesto iOS anula el padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.only(top: 47),
            viewInsets: EdgeInsets.only(top: 47),
          ),
          child: TwDetailScaffold(
            eyebrow: 'Detalle del evento',
            title: 'Evento',
            onBack: () {},
            children: const [SizedBox(height: 400)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byType(TwIconButton).first).dy,
      47 + TwDetailBarMetrics.gapVertical,
    );
  });

  testWidgets('el menú llena el viewport y no rebota al overscroll', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: TwDetailScaffold(
          eyebrow: 'Detalle de la actividad',
          title: 'Campaña',
          onBack: _noop,
          children: [SizedBox(height: 80, child: Text('Acciones'))],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.widget<Scrollable>(find.byType(Scrollable));
    expect(scrollable.physics, isA<AlwaysScrollableScrollPhysics>());
    expect(
      (scrollable.physics as AlwaysScrollableScrollPhysics).parent,
      isA<ClampingScrollPhysics>(),
    );

    final cuerpo = tester.widget<ConstrainedBox>(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(ConstrainedBox),
      ),
    );
    expect(cuerpo.constraints.minHeight, greaterThan(600));
  });

  testWidgets('el contenido arranca bajo la barra, no debajo del atrás', (
    tester,
  ) async {
    await montarLista(tester, padding: EdgeInsets.zero);
    await tester.pumpAndSettle();

    final metricas = tester.element(find.byType(CollapsingScrollScaffold));
    final overlayH = CollapsingNavMetrics(
      metricas,
    ).overlayHeight(conAcciones: true);

    expect(
      overlayH,
      CollapsingNavMetrics.gapTop +
          CollapsingNavMetrics.titleZone +
          CollapsingNavMetrics.gapActionsBottom,
    );
    expect(
      tester.getBottomLeft(find.byType(CollapsingNavButton)).dy,
      lessThanOrEqualTo(overlayH),
    );
  });

  testWidgets('el pull-to-refresh nace bajo el buscador fijado', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CollapsingScrollScaffold(
          title: 'Eventos',
          alwaysShowActions: true,
          overlayLeading: CollapsingNavButton(
            icon: Symbols.arrow_back_rounded,
            onTap: () {},
          ),
          pinnedContentHeight: 112,
          pinnedContent: const SizedBox(height: 112),
          onRefresh: () async {},
          slivers: const [
            SliverToBoxAdapter(child: SizedBox(height: 48, child: Text('Título'))),
            SliverToBoxAdapter(child: SizedBox(height: 800)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(CollapsingScrollScaffold));
    final overlayH = CollapsingNavMetrics(
      context,
    ).overlayHeight(conAcciones: true);
    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    expect(indicator.edgeOffset, greaterThan(overlayH));
    expect(indicator.edgeOffset, overlayH + 48 + 112);
  });

  testWidgets('con lista vacía el scroll queda bloqueado', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CollapsingScrollScaffold(
          title: 'Leads',
          lockScroll: true,
          onRefresh: () async {},
          slivers: const [
            SliverToBoxAdapter(
              child: SizedBox(height: 80, child: Text('0 leads')),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('Aún no hay leads capturados en este evento.'),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsNothing);
    expect(
      tester.widget<CustomScrollView>(find.byType(CustomScrollView)).physics,
      isA<NeverScrollableScrollPhysics>(),
    );

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.pixels, 0);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
    await tester.pump();

    expect(scrollable.position.pixels, 0);
  });

  test('el blur espera a que el header toque el borde superior', () {
    const overlay = CollapsingNavOverlay(
      scrollOffset: 0,
      title: 'Eventos',
      collapseStart: 12,
    );
    expect(overlay.bgOpacity, 0);
    expect(overlay.titleOpacity, 0);

    const alTocar = CollapsingNavOverlay(
      scrollOffset: 12,
      title: 'Eventos',
      collapseStart: 12,
    );
    expect(alTocar.bgOpacity, 0);
    expect(alTocar.titleOpacity, 0);

    const aMedia = CollapsingNavOverlay(
      scrollOffset: 22,
      title: 'Eventos',
      collapseStart: 12,
    );
    expect(aMedia.bgOpacity, 0.5);

    const opaco = CollapsingNavOverlay(
      scrollOffset: 32,
      title: 'Eventos',
      collapseStart: 12,
    );
    expect(opaco.bgOpacity, 1);
    expect(opaco.titleOpacity, 1);
  });

  testWidgets('con acciones el colapso arranca al tocar el atrás', (
    tester,
  ) async {
    late CollapsingNavMetrics metricas;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            metricas = CollapsingNavMetrics(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      metricas.collapseStart(conAcciones: false),
      CollapsingNavMetrics.gapTop,
    );
    expect(
      metricas.collapseStart(conAcciones: true),
      CollapsingNavMetrics.gapActionsBottom,
    );
  });
}
