import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../core/widgets/pressable.dart';
import '../models/home_featured_item.dart';

/// Card del header del home: próximo evento, o slider de fijados.
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

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    if (!_esSlider) {
      return _FeaturedSlide(item: widget.items.first, showPin: false);
    }

    final textScaler = MediaQuery.textScalerOf(context);
    final dateScale = textScaler.scale(1).clamp(1.0, double.infinity);
    final contentScale = (textScaler.scale(14) / 14).clamp(
      1.0,
      double.infinity,
    );
    final contentHeight = 76 * contentScale;
    final dateHeight = 56 * dateScale;
    final cardHeight =
        32 + (contentHeight > dateHeight ? contentHeight : dateHeight);

    return Column(
      children: [
        SizedBox(
          height: cardHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.items.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _FeaturedSlide(
                  key: ValueKey('${item.kind.name}-${item.id}'),
                  item: item,
                  showPin: item.esFijado,
                ),
              );
            },
          ),
        ),
        if (widget.items.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.items.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                AnimatedContainer(
                  duration: AppMotion.toggle,
                  curve: AppMotion.ease,
                  width: i == _page ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: i == _page ? 0.95 : 0.45,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _FeaturedSlide extends StatelessWidget {
  const _FeaturedSlide({super.key, required this.item, required this.showPin});

  final HomeFeaturedItem item;
  final bool showPin;

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat('EEEE d MMM', 'es').format(item.fecha);
    final etiquetaColor = item.esFijado ? AppColors.primary : AppColors.success;

    return Pressable(
      onTap: () => context.push(item.routePath),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(AppRadius.fab),
          boxShadow: AppColors.shadowHero,
        ),
        child: Row(
          children: [
            DateTile(date: item.fecha, hero: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      if (showPin)
                        Icon(
                          Symbols.push_pin_rounded,
                          size: 12,
                          color: etiquetaColor,
                        )
                      else
                        const _PulseDot(),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          item.etiqueta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: etiquetaColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [fecha, if (item.lugar.isNotEmpty) item.lugar].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Symbols.chevron_right_rounded,
              color: AppColors.chevronMuted,
            ),
          ],
        ),
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
          color: AppColors.success,
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
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
