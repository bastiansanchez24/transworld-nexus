import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tw_tokens.dart';
import '../../../core/widgets/evento_hero_banner.dart';
import '../../../core/widgets/tw_components.dart';
import '../models/home_featured_item.dart';

/// Gutter que alinea la card centrada con el resto del home.
double homeFeaturedSettledInset(double width) {
  final contentWidth = math.min(
    AppSpacing.contentMax,
    math.max(0.0, width - TwSpacing.screenH * 2),
  );
  return (width - contentWidth) / 2;
}

/// Card del home: próximo evento, o slider de fijados.
///
/// Rediseño: hero navy radio 22, métricas separadas por hairline y dos CTA de
/// 48 dp (blanco + fantasma), según el prototipo de la pantalla de inicio.
class ProximoEventoCard extends StatefulWidget {
  const ProximoEventoCard({super.key, required this.items});

  final List<HomeFeaturedItem> items;

  @override
  State<ProximoEventoCard> createState() => _ProximoEventoCardState();
}

class _ProximoEventoCardState extends State<ProximoEventoCard> {
  late final PageController _pageController;
  int _page = 0;

  bool get _esSlider =>
      widget.items.length > 1 ||
      (widget.items.isNotEmpty && widget.items.first.esFijado);

  void _irAPagina(int pagina) {
    if (pagina < 0 || pagina >= widget.items.length) return;
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      pagina,
      duration: AppMotion.toggle,
      curve: AppMotion.ease,
    );
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant ProximoEventoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length ||
        !_mismaLista(oldWidget.items, widget.items)) {
      _page = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _mismaLista(List<HomeFeaturedItem> a, List<HomeFeaturedItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].kind != b[i].kind) return false;
    }
    return true;
  }

  double _alturaCard(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    // 296 dp cubren el caso peor del mock: título de 2 líneas + métricas + los
    // dos CTA de 48. Lo que sobre lo comprime el FittedBox del slide.
    return 36 + 296 * scale;
  }

  double _pageValue() {
    if (!_pageController.hasClients) return _page.toDouble();
    return _pageController.page ?? _page.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final settledInset = homeFeaturedSettledInset(width);

        if (!_esSlider) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: settledInset),
            child: _FeaturedSlide(item: widget.items.first),
          );
        }

        final cardHeight = _alturaCard(context);

        return Column(
          children: [
            SizedBox(
              height: cardHeight,
              child: AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  final page = _pageValue();
                  final fractional = (page - page.roundToDouble()).abs();
                  final shadowInset = settledInset * (1 - fractional);
                  return Stack(
                    children: [
                      // La sombra se pinta fuera del PageView: dentro, el
                      // viewport la corta en recto y deja un rectángulo.
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: shadowInset,
                          ),
                          child: const IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: TwRadii.hero,
                                boxShadow: TwShadows.hero,
                              ),
                            ),
                          ),
                        ),
                      ),
                      child!,
                    ],
                  );
                },
                child: _CarruselBordeSuave(
                  child: ScrollConfiguration(
                    // La card ocupa todo el ancho y ya no hay flechas
                    // laterales: en web y Windows el arrastre con mouse es
                    // la única alternativa al swipe.
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: const {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                        PointerDeviceKind.stylus,
                      },
                    ),
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: widget.items.length,
                      onPageChanged: (page) => setState(() => _page = page),
                      itemBuilder: (context, index) {
                        final item = widget.items[index];
                        return AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            final page = _pageValue();
                            final t = (1.0 - (index - page).abs()).clamp(
                              0.0,
                              1.0,
                            );
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: settledInset * t,
                              ),
                              child: child,
                            );
                          },
                          child: _FeaturedSlide(
                            key: ValueKey('${item.kind.name}-${item.id}'),
                            item: item,
                            conSombra: false,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            if (widget.items.length > 1) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.items.length; i++)
                    _PuntoCarrusel(
                      key: Key('proximo_evento_punto_$i'),
                      activo: i == _page,
                      posicion: i + 1,
                      total: widget.items.length,
                      onTap: () => _irAPagina(i),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Fade corto en los bordes de la pantalla: la card se disuelve al salir,
/// sin un bloque de blur que corte contra el resto del home.
class _CarruselBordeSuave extends StatelessWidget {
  const _CarruselBordeSuave({required this.child});

  final Widget child;

  static const _fadePx = 16.0;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) return child;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final fade = (_fadePx / rect.width).clamp(0.0, 0.12);
        return LinearGradient(
          colors: const [
            Color(0x00FFFFFF),
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [0.0, fade, 1.0 - fade, 1.0],
        ).createShader(rect);
      },
      child: child,
    );
  }
}

/// Viñeta del carrusel. Inactivas con contraste alto para contar cuántas hay.
class _PuntoCarrusel extends StatelessWidget {
  const _PuntoCarrusel({
    super.key,
    required this.activo,
    required this.posicion,
    required this.total,
    required this.onTap,
  });

  final bool activo;
  final int posicion;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activo,
      label: 'Card $posicion de $total',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: AnimatedContainer(
            duration: AppMotion.toggle,
            curve: AppMotion.ease,
            width: activo ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: activo
                  ? TwColors.hero700
                  : TwColors.hero700.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedSlide extends StatelessWidget {
  const _FeaturedSlide({super.key, required this.item, this.conSombra = true});

  final HomeFeaturedItem item;

  /// En el carrusel la sombra la pinta el fondo del Stack, no cada slide.
  final bool conSombra;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: TwGradients.hero,
        borderRadius: TwRadii.hero,
        boxShadow: conSombra ? TwShadows.hero : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (item.tieneImagen)
            Positioned.fill(
              child: EventoHeroFoto(imagenUrl: item.imagenUrl!, velo: 0),
            ),
          // Velo sobre foto o degradado: el texto blanco y las métricas leen.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: TwGradients.homeScrim),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          item.esFijado
                              ? Symbols.push_pin_rounded
                              : Symbols.schedule_rounded,
                          size: 15,
                          fill: 1,
                          color: TwColors.whiteA75,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.etiqueta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TwText.homeEyebrow,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: TwColors.whiteA16,
                            borderRadius: TwRadii.pill,
                            border: Border.all(color: TwColors.whiteA16),
                          ),
                          child: Text(
                            formatearDiaMesCorto(item.fecha),
                            style: TwText.homeDateChip,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TwText.homeHeroTitle,
                    ),
                    if (item.lugar.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Symbols.location_on_rounded,
                            size: 16,
                            color: TwColors.whiteA66,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              item.lugar,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TwText.heroMeta,
                            ),
                          ),
                        ],
                      ),
                    ],
                    _HomeStats(
                      registrados: '${item.registrados}',
                      acreditados: item.porcentajeAcreditados,
                      leads: '${item.leads}',
                    ),
                    _HeroCta(
                      label: item.ctaLabel,
                      filled: true,
                      onTap: () => context.push(item.routePath),
                    ),
                    if (item.qrRoutePath != null) ...[
                      const SizedBox(height: 10),
                      _HeroCta(
                        key: Key('proximo_evento_escanear_qr_${item.id}'),
                        label: 'Escanear QR',
                        icon: Symbols.qr_code_scanner_rounded,
                        filled: false,
                        onTap: () => context.push(item.qrRoutePath!),
                      ),
                    ],
                  ],
                );
                if (!constraints.maxHeight.isFinite) return content;
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: SizedBox(width: constraints.maxWidth, child: content),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Métricas del hero del home: tres columnas de igual ancho separadas por un
/// hairline al 14 % de blanco.
class _HomeStats extends StatelessWidget {
  const _HomeStats({
    required this.registrados,
    required this.acreditados,
    required this.leads,
  });

  final String registrados;
  final String acreditados;
  final String leads;

  @override
  Widget build(BuildContext context) {
    final columnas = <(String, String)>[
      (registrados, 'REGISTRADOS'),
      (acreditados, 'ACREDITADOS'),
      (leads, 'LEADS'),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < columnas.length; i++)
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: i == 0
                        ? null
                        : const Border(
                            left: BorderSide(color: TwColors.whiteA14),
                          ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          columnas[i].$1,
                          maxLines: 1,
                          style: TwText.homeStatValue,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          columnas[i].$2,
                          maxLines: 1,
                          style: TwText.homeStatLabel,
                        ),
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

/// CTA del hero: blanco (principal) o fantasma sobre el navy.
class _HeroCta extends StatelessWidget {
  const _HeroCta({
    super.key,
    required this.label,
    required this.filled,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = filled ? TwColors.deepInk : Colors.white;

    return TwPressable(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: filled ? TwColors.surface : TwColors.whiteA14,
          borderRadius: TwRadii.button,
          border: filled
              ? null
              : Border.all(color: TwColors.whiteA22),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: filled ? TwText.heroCta : TwText.heroCtaGhost,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
