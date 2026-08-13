import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/browser_theme_color.dart';
import 'pressable.dart';

enum CollapsingNavStyle { standard, home, detail }

/// Medidas de la barra colapsable adaptadas al safe area real.
class CollapsingNavMetrics {
  CollapsingNavMetrics(BuildContext context)
    : topInset = MediaQuery.paddingOf(context).top;

  final double topInset;

  static const double titleZone = 44;

  /// Aire sobre los botones de la barra. Hace falta en todas las cabeceras:
  /// en web y en Windows no hay notch ni barra de estado que empuje el
  /// contenido, así que con [topInset] en 0 el "atrás" quedaba pegado al
  /// borde superior de la ventana.
  static const double gapTop = 12;

  /// Aire bajo los botones en las cabeceras de detalle
  /// ([CollapsingNavStyle.detail]), que van sobre el hero del evento: sin
  /// esto el "atrás" y el lápiz quedan pegados al contenido del hero.
  static const double gapDetail = 12;

  double get barHeight => topInset + gapTop + titleZone;

  double get barWithSearch => barHeight + 56;
}

/// Overlay sticky con blur scroll-driven (HANDOFF §4.1).
class CollapsingNavOverlay extends StatelessWidget {
  const CollapsingNavOverlay({
    super.key,
    required this.scrollOffset,
    required this.title,
    this.style = CollapsingNavStyle.standard,
    this.extendedHeight,
    this.leading,
    this.trailing,
    this.alwaysShowActions = false,

    /// Distancia de scroll hasta que el buscador toca el título colapsado.
    /// Alinea fade del título/blur con ese momento.
    this.collapseExtent = 48,
  });

  final double scrollOffset;
  final String title;
  final CollapsingNavStyle style;
  final double? extendedHeight;
  final Widget? leading;
  final Widget? trailing;
  final bool alwaysShowActions;
  final double collapseExtent;

  double get _extent => collapseExtent <= 0 ? 48.0 : collapseExtent;

  double get bgOpacity => (scrollOffset / _extent).clamp(0.0, 1.0);

  /// El título colapsado queda opaco antes de que el buscador se fije.
  double get titleOpacity {
    final start = _extent * 0.18;
    final end = _extent * 0.82;
    final range = (end - start).clamp(1.0, _extent);
    return ((scrollOffset - start) / range).clamp(0.0, 1.0);
  }

  double get titleTranslateY => (1 - titleOpacity) * 6;

  @override
  Widget build(BuildContext context) {
    final metrics = CollapsingNavMetrics(context);
    final isHome = style == CollapsingNavStyle.home;
    final isDetail = style == CollapsingNavStyle.detail;
    final gapInferior = isDetail ? CollapsingNavMetrics.gapDetail : 0.0;
    final height = extendedHeight ?? (metrics.barHeight + gapInferior);

    final SystemUiOverlayStyle overlayStyle;
    if (isHome) {
      overlayStyle = SystemUiOverlayStyle.light;
    } else if (isDetail) {
      overlayStyle = scrollOffset > 40
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light;
    } else {
      overlayStyle = SystemUiOverlayStyle.dark;
    }

    final titleColor = isHome ? Colors.white : AppColors.ink;
    final borderColor = isHome
        ? Colors.white.withValues(alpha: 0.12 * bgOpacity)
        : Color.fromRGBO(13, 42, 74, 0.08 * bgOpacity);

    final showActions = alwaysShowActions || titleOpacity > 0.05;
    final showBlur = bgOpacity > 0.01;

    final browserThemeColor = overlayStyle == SystemUiOverlayStyle.light
        ? AppColors.primaryDeep
        : AppColors.background;

    return BrowserThemeColor(
      color: browserThemeColor,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              // Bloquea taps en toda la zona de la navbar; sin esto el scroll
              // recibe toques en áreas sin widget interactivo (título, blur, etc.).
              Positioned.fill(
                child: AbsorbPointer(child: const SizedBox.expand()),
              ),
              if (showBlur)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRect(
                      // Blur visible sin volver a sigma 22 (afectaba scroll en listas).
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: isHome
                                ? null
                                : AppColors.background.withValues(
                                    alpha: 0.30 * bgOpacity,
                                  ),
                            gradient: isHome
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color.fromRGBO(
                                        12,
                                        51,
                                        87,
                                        0.55 * bgOpacity,
                                      ),
                                      Color.fromRGBO(
                                        23,
                                        94,
                                        147,
                                        0.55 * bgOpacity,
                                      ),
                                    ],
                                  )
                                : null,
                            border: Border(
                              bottom: BorderSide(color: borderColor, width: 1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: metrics.topInset + CollapsingNavMetrics.gapTop,
                left: 0,
                right: 0,
                height: CollapsingNavMetrics.titleZone,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: (showActions && leading != null)
                            ? Center(child: leading)
                            : null,
                      ),
                      Expanded(
                        child: Opacity(
                          opacity: titleOpacity,
                          child: Transform.translate(
                            offset: Offset(0, titleTranslateY),
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: titleColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: (showActions && trailing != null)
                            ? Center(child: trailing)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CollapsingNavButton extends StatelessWidget {
  const CollapsingNavButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.9,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 17, color: AppColors.ink),
      ),
    );
  }
}

/// Botón cuadrado al lado del buscador fijado (misma altura y estilo).
class PinnedSearchActionButton extends StatelessWidget {
  const PinnedSearchActionButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.9,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.shadowRest,
        ),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, size: 22, color: AppColors.ink),
        ),
      ),
    );
  }
}

/// Ancla al inicio del bloque fijable; reporta la extensión del título grande
/// (scroll necesario para que el buscador toque la navbar colapsada).
class _PinThresholdAnchor extends StatefulWidget {
  const _PinThresholdAnchor({required this.topSpacer, required this.onExtent});

  final double topSpacer;
  final ValueChanged<double> onExtent;

  @override
  State<_PinThresholdAnchor> createState() => _PinThresholdAnchorState();
}

class _PinThresholdAnchorState extends State<_PinThresholdAnchor> {
  double? _lastReported;
  bool _measureScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant _PinThresholdAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topSpacer != widget.topSpacer) {
      _scheduleMeasure();
    }
  }

  void _scheduleMeasure() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      _measure();
    });
  }

  void _measure() {
    if (!mounted) return;
    final ro = context.findRenderObject();
    if (ro == null || !ro.attached) return;
    final viewport = RenderAbstractViewport.maybeOf(ro);
    if (viewport == null) return;

    final offsetToViewportTop = viewport.getOffsetToReveal(ro, 0.0).offset;
    final extent = (offsetToViewportTop - widget.topSpacer).clamp(0.0, 400.0);
    if (_lastReported != null && (extent - _lastReported!).abs() <= 0.5) {
      return;
    }
    _lastReported = extent;
    widget.onExtent(extent);
  }

  @override
  Widget build(BuildContext context) {
    // Cada rebuild del header (p. ej. al cargar conteos) vuelve a medir.
    _scheduleMeasure();
    return const SizedBox(width: double.infinity, height: 0);
  }
}

/// Pantalla scrollable con overlay colapsable.
class CollapsingScrollScaffold extends StatefulWidget {
  const CollapsingScrollScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.style = CollapsingNavStyle.standard,
    this.floatingActionButton,
    this.overlayTrailing,
    this.overlayLeading,
    this.pinnedSearch,
    this.pinnedContent,
    this.pinnedContentHeight = 56,
    this.alwaysShowActions = false,
    this.topBanner,
    this.onRefresh,

    /// Si cambia (p. ej. query/filtro), el scroll vuelve arriba para no dejar
    /// filas “volando” con el offset anterior.
    this.scrollResetToken,
  }) : assert(pinnedSearch == null || pinnedContent == null);

  final String title;

  /// Contenido scrollable. Si hay [pinnedContent] o [pinnedSearch], el primer
  /// sliver debe ser el título grande; el contenido fijable se inserta después.
  final List<Widget> slivers;
  final CollapsingNavStyle style;
  final Widget? floatingActionButton;
  final Widget? overlayTrailing;
  final Widget? overlayLeading;

  /// Alias histórico para un único buscador fijado.
  final Widget? pinnedSearch;

  /// Contenido que pasa del flujo normal a quedar fijo bajo la navbar.
  /// Puede contener un buscador, filtros o ambos.
  final Widget? pinnedContent;
  final double pinnedContentHeight;
  final bool alwaysShowActions;
  final Widget? topBanner;
  final Future<void> Function()? onRefresh;
  final Object? scrollResetToken;

  Widget? get effectivePinnedContent => pinnedContent ?? pinnedSearch;

  /// Padding idéntico in-flow y fijado (evita saltos de chips/buscador).
  static const pinnedPadding = EdgeInsets.fromLTRB(20, 4, 20, 8);

  @override
  State<CollapsingScrollScaffold> createState() =>
      _CollapsingScrollScaffoldState();
}

class _CollapsingScrollScaffoldState extends State<CollapsingScrollScaffold> {
  final ValueNotifier<double> _scrollY = ValueNotifier(0);
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<NestedScrollViewState> _nestedKey =
      GlobalKey<NestedScrollViewState>();

  /// Extensión del título grande: el buscador se fija al alcanzarla.
  double _collapseExtent = 48.0;

  @override
  void initState() {
    super.initState();
    // Escucha el scroll exterior (NestedScrollView) o el único CustomScrollView.
    // Así el pull-to-refresh del body no reinicia el offset del overlay.
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant CollapsingScrollScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollResetToken != widget.scrollResetToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _resetScroll();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollY.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    _onScroll(_scrollController.offset);
  }

  void _resetScroll() {
    // Solo resetea offset: el buscador vive siempre en el overlay, así
    // el TextField no se desmonta y el teclado/foco se mantienen.
    //
    // El inner se resetea primero (por si hubiera un NestedScrollView, cuyo
    // coordinador re-empuja el outer si el inner sigue scrolleado) y _scrollY
    // toma el offset real, no un 0 asumido, para no desincronizarse de la lista.
    final inner = _nestedKey.currentState?.innerController;
    if (inner != null && inner.hasClients) {
      inner.jumpTo(0);
    }
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _scrollY.value = _scrollController.hasClients
        ? _scrollController.offset
        : 0;
  }

  void _onCollapseExtent(double extent) {
    if ((extent - _collapseExtent).abs() <= 0.5) return;
    setState(() => _collapseExtent = extent);
  }

  void _onScroll(double y) {
    // Umbral bajo para que el fade del overlay se sienta fluido a 120 Hz.
    if ((y - _scrollY.value).abs() <= 0.1) return;
    _scrollY.value = y;
  }

  List<Widget> _pinnedHeaderSlivers(CollapsingNavMetrics metrics) {
    final header = widget.slivers.isEmpty ? null : widget.slivers.first;
    return [
      ?header,
      // Ancla justo encima del bloque fijable → extent = alto del título.
      SliverToBoxAdapter(
        child: _PinThresholdAnchor(
          topSpacer: metrics.barHeight,
          onExtent: _onCollapseExtent,
        ),
      ),
      // Solo reserva espacio: el buscador real vive en el Stack para no
      // recrear el TextField al fijar/desfijar (y al resetear el scroll).
      SliverToBoxAdapter(child: SizedBox(height: widget.pinnedContentHeight)),
    ];
  }

  List<Widget> _listSlivers() {
    if (widget.slivers.length <= 1) return const <Widget>[];
    return widget.slivers.sublist(1);
  }

  static const _scrollPhysics = BouncingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );

  Widget _buildScrollable({
    required CollapsingNavMetrics metrics,
    required bool hasPinnedContent,
  }) {
    final topSpacer = [
      SliverToBoxAdapter(child: SizedBox(height: metrics.barHeight)),
    ];
    final bottomSpacer = [
      SliverToBoxAdapter(
        child: SizedBox(height: GlassNavTokens.contentBottomInset(context)),
      ),
    ];

    // Un único CustomScrollView (sin NestedScrollView): con contenido más corto
    // que la pantalla el maxScrollExtent es 0, así el título/lista no pueden
    // colapsar dejando el único ítem escondido tras la navbar. El NestedScrollView
    // colapsaba su cabecera siempre, sin importar el largo del cuerpo.
    final List<Widget> contentSlivers;
    if (!hasPinnedContent) {
      contentSlivers = widget.slivers;
    } else {
      contentSlivers = [..._pinnedHeaderSlivers(metrics), ..._listSlivers()];
    }

    final scrollView = CustomScrollView(
      controller: _scrollController,
      physics: _scrollPhysics,
      slivers: [...topSpacer, ...contentSlivers, ...bottomSpacer],
    );

    if (widget.onRefresh != null) {
      return RefreshIndicator(
        color: AppColors.primary,
        edgeOffset: metrics.barHeight,
        onRefresh: widget.onRefresh!,
        child: scrollView,
      );
    }
    return scrollView;
  }

  @override
  Widget build(BuildContext context) {
    final metrics = CollapsingNavMetrics(context);
    final pinnedContent = widget.effectivePinnedContent;
    final hasPinnedContent = pinnedContent != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: widget.floatingActionButton == null
          ? null
          : Padding(
              // Scaffold anidado bajo MainShellScaffold: el FAB no se eleva
              // solo con extendBody del padre; hay que despejar la tab bar.
              padding: const EdgeInsets.only(bottom: AppSpacing.shellFabBottom),
              child: widget.floatingActionButton,
            ),
      body: Column(
        children: [
          ?widget.topBanner,
          Expanded(
            child: Stack(
              children: [
                _buildScrollable(
                  metrics: metrics,
                  hasPinnedContent: hasPinnedContent,
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: RepaintBoundary(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _scrollY,
                      builder: (context, scrollY, _) {
                        final overlayH =
                            hasPinnedContent && scrollY >= _collapseExtent
                            ? metrics.barHeight + widget.pinnedContentHeight
                            : metrics.barHeight;
                        return CollapsingNavOverlay(
                          scrollOffset: scrollY,
                          title: widget.title,
                          style: widget.style,
                          extendedHeight: overlayH,
                          collapseExtent: _collapseExtent,
                          leading: widget.overlayLeading,
                          trailing: widget.overlayTrailing,
                          alwaysShowActions: widget.alwaysShowActions,
                        );
                      },
                    ),
                  ),
                ),
                if (hasPinnedContent)
                  Positioned.fill(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _scrollY,
                      builder: (context, scrollY, child) {
                        // Sigue el hueco del spacer hasta fijarse bajo la navbar.
                        // Sin tope superior: en overscroll (pull-to-refresh,
                        // scrollY negativo) acompaña al contenido hacia abajo en
                        // vez de quedarse clavado mientras el resto hace rubber-band.
                        final top =
                            metrics.barHeight +
                            (_collapseExtent - scrollY).clamp(
                              0.0,
                              double.infinity,
                            );
                        return Stack(
                          children: [
                            Positioned(
                              top: top,
                              left: 0,
                              right: 0,
                              height: widget.pinnedContentHeight,
                              child: child!,
                            ),
                          ],
                        );
                      },
                      child: Padding(
                        padding: CollapsingScrollScaffold.pinnedPadding,
                        child: pinnedContent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
