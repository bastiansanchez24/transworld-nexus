import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/evento_hero_banner.dart';
import '../../../core/widgets/pressable.dart';
import '../models/home_featured_item.dart';

/// Gutter que alinea la card centrada con el resto del home.
double homeFeaturedSettledInset(double width) {
  final contentWidth = math.min(
    AppSpacing.contentMax,
    math.max(0.0, width - AppSpacing.screenH * 2),
  );
  return (width - contentWidth) / 2;
}

/// Card del home: próximo evento, o slider de fijados.
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
    return 36 + 280 * scale;
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
            child: _FeaturedSlide(item: widget.items.first, showPin: false),
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
                                borderRadius: BorderRadius.all(
                                  Radius.circular(26),
                                ),
                                boxShadow: AppColors.shadowHeroCard,
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
                            showPin: item.esFijado,
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
                  ? AppColors.heroNavy
                  : AppColors.identityAccent.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedSlide extends StatelessWidget {
  const _FeaturedSlide({
    super.key,
    required this.item,
    required this.showPin,
    this.conSombra = true,
  });

  final HomeFeaturedItem item;
  final bool showPin;

  /// En el carrusel la sombra la pinta el fondo del Stack, no cada slide.
  final bool conSombra;

  String get _fechaChip {
    final raw = DateFormat('d MMM', 'es').format(item.fecha);
    return raw.replaceAll('.', '').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final etiquetaColor = showPin ? Colors.white : AppColors.live;

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: conSombra ? AppColors.shadowHeroCard : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (item.tieneImagen)
            Positioned.fill(child: EventoHeroFoto(imagenUrl: item.imagenUrl!))
          else
            Positioned(
              top: -52,
              right: -38,
              child: IgnorePointer(
                child: Container(
                  width: 168,
                  height: 168,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (showPin)
                          Icon(
                            Symbols.push_pin_rounded,
                            size: 12,
                            color: etiquetaColor,
                            fill: 1,
                          )
                        else
                          const _PulseDot(),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.etiqueta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.9,
                              color: etiquetaColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.42),
                            ),
                          ),
                          child: Text(
                            _fechaChip,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.28,
                        letterSpacing: -0.35,
                        color: Colors.white,
                      ),
                    ),
                    if (item.lugar.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Symbols.location_on_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.92),
                            fill: 1,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.lugar,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricTile(
                            value: '${item.registrados}',
                            label: 'REGISTRADOS',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricTile(
                            value: item.porcentajeAcreditados,
                            label: 'ACREDITADOS',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricTile(
                            value: '${item.leads}',
                            label: 'LEADS',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _HeroCta(
                      label: item.ctaLabel,
                      icon: Symbols.arrow_forward_rounded,
                      iconAlFinal: true,
                      filled: true,
                      onTap: () => context.push(item.routePath),
                    ),
                    if (item.qrRoutePath != null) ...[
                      const SizedBox(height: 8),
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

class _HeroCta extends StatelessWidget {
  const _HeroCta({
    super.key,
    required this.label,
    required this.icon,
    this.iconAlFinal = false,
    this.filled = true,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool iconAlFinal;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = filled ? AppColors.heroNavy : Colors.white;
    final child = Container(
      height: 44,
      decoration: BoxDecoration(
        color: filled ? Colors.white : Colors.white.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(15),
        border: filled
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!iconAlFinal) ...[
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            if (iconAlFinal) ...[
              const SizedBox(width: 6),
              Icon(icon, size: 19, color: color),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return child;
    return Pressable(scale: 0.98, onTap: onTap, child: child);
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: Colors.white.withValues(alpha: 0.90),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) {
      return Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: AppColors.live,
          shape: BoxShape.circle,
        ),
      );
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = (_ctrl.value < 0.5)
            ? (_ctrl.value * 2)
            : (1 - (_ctrl.value - 0.5) * 2);
        final scale = 1 + 0.5 * t;
        final opacity = 1 - 0.5 * t;
        return Transform.scale(
          scale: scale,
          child: Opacity(opacity: opacity, child: child),
        );
      },
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: AppColors.live,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
