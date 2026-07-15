import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'pressable.dart';

enum CollapsingNavStyle { standard, home, detail }

/// Medidas de la barra colapsable adaptadas al safe area real.
class CollapsingNavMetrics {
  CollapsingNavMetrics(BuildContext context)
    : topInset = MediaQuery.paddingOf(context).top;

  final double topInset;

  static const double titleZone = 44;

  double get barHeight => topInset + titleZone;

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
  });

  final double scrollOffset;
  final String title;
  final CollapsingNavStyle style;
  final double? extendedHeight;
  final Widget? leading;
  final Widget? trailing;
  final bool alwaysShowActions;

  double get bgOpacity => (scrollOffset / 48).clamp(0.0, 1.0);
  double get titleOpacity => ((scrollOffset - 28) / 30).clamp(0.0, 1.0);
  double get titleTranslateY => (1 - titleOpacity) * 6;

  @override
  Widget build(BuildContext context) {
    final metrics = CollapsingNavMetrics(context);
    final height = extendedHeight ?? metrics.barHeight;
    final isHome = style == CollapsingNavStyle.home;
    final isDetail = style == CollapsingNavStyle.detail;

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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            if (showBlur)
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRect(
                    // Blur moderado: sigma 22 por frame mataba el scroll
                    // en Eventos/Leads (listas bajo este overlay).
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isHome
                              ? null
                              : AppColors.background.withValues(
                                  alpha: 0.88 * bgOpacity,
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
                                      0.88 * bgOpacity,
                                    ),
                                    Color.fromRGBO(
                                      23,
                                      94,
                                      147,
                                      0.88 * bgOpacity,
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
              top: metrics.topInset,
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
                      child: IgnorePointer(
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

  Widget? get effectivePinnedContent => pinnedContent ?? pinnedSearch;

  @override
  State<CollapsingScrollScaffold> createState() =>
      _CollapsingScrollScaffoldState();
}

class _CollapsingScrollScaffoldState extends State<CollapsingScrollScaffold> {
  final ValueNotifier<double> _scrollY = ValueNotifier(0);
  bool _contentPinned = false;
  static const _pinAfter = 48.0;

  @override
  void dispose() {
    _scrollY.dispose();
    super.dispose();
  }

  void _onScroll(double y) {
    if ((y - _scrollY.value).abs() <= 0.5) return;
    _scrollY.value = y;

    // Solo reconstruir la lista al cruzar el umbral del contenido fijo.
    if (widget.effectivePinnedContent == null) return;
    final pinned = y >= _pinAfter;
    if (pinned != _contentPinned) {
      setState(() => _contentPinned = pinned);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = CollapsingNavMetrics(context);
    final pinnedContent = widget.effectivePinnedContent;
    final hasPinnedContent = pinnedContent != null;

    final List<Widget> contentSlivers;
    if (!hasPinnedContent) {
      contentSlivers = widget.slivers;
    } else {
      final header = widget.slivers.isEmpty ? null : widget.slivers.first;
      final rest = widget.slivers.length <= 1
          ? const <Widget>[]
          : widget.slivers.sublist(1);
      contentSlivers = [
        ?header,
        SliverToBoxAdapter(
          child: SizedBox(
            height: widget.pinnedContentHeight,
            child: _contentPinned
                ? null
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: pinnedContent,
                  ),
          ),
        ),
        ...rest,
      ];
    }

    final scrollView = CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: metrics.barHeight)),
        ...contentSlivers,
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );

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
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.axis == Axis.vertical) {
                  _onScroll(n.metrics.pixels);
                }
                return false;
              },
              child: Stack(
                children: [
                  if (widget.onRefresh != null)
                    RefreshIndicator(
                      color: AppColors.primary,
                      edgeOffset: metrics.barHeight,
                      onRefresh: widget.onRefresh!,
                      child: scrollView,
                    )
                  else
                    scrollView,
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: RepaintBoundary(
                      child: ValueListenableBuilder<double>(
                        valueListenable: _scrollY,
                        builder: (context, scrollY, _) {
                          final overlayH =
                              hasPinnedContent && scrollY >= _pinAfter
                              ? metrics.barHeight + widget.pinnedContentHeight
                              : metrics.barHeight;
                          return CollapsingNavOverlay(
                            scrollOffset: scrollY,
                            title: widget.title,
                            style: widget.style,
                            extendedHeight: overlayH,
                            leading: widget.overlayLeading,
                            trailing: widget.overlayTrailing,
                            alwaysShowActions: widget.alwaysShowActions,
                          );
                        },
                      ),
                    ),
                  ),
                  if (_contentPinned)
                    Positioned(
                      top: metrics.barHeight + 4,
                      left: 20,
                      right: 20,
                      child: SizedBox(
                        height: widget.pinnedContentHeight - 8,
                        child: pinnedContent,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
