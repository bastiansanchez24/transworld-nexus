import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tw_tokens.dart';
import 'pressable.dart';

class TwNavItemData {
  const TwNavItemData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Bottom navbar flotante del prototipo: panel de 68 dp, radio 26 y doble
/// sombra, con el mismo blur de las cabeceras colapsables (sigma 18 y velo
/// al 30%). El ítem activo se marca con un chip 46×30 de fondo azul tenue,
/// borde navy de 1.5 y el icono en FILL 1.
///
/// La navegación real queda fuera: este widget solo pinta y reporta el índice.
class TwBottomNavBar extends StatelessWidget {
  const TwBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<TwNavItemData> items;

  /// Igual que [CollapsingNavOverlay] / [TwDetailScaffold]: visible sin
  /// volver a sigma 22 (afectaba el scroll en listas).
  static const _blurSigma = 18.0;

  /// Tint sobre el blur: el overlay colapsable usa 0.30 de fondo.
  static const _fillAlpha = 0.30;

  /// `0 -2px 30px rgba(16,35,64,.12)` + `0 8px 24px -10px rgba(16,35,64,.2)`.
  static const _shadow = [
    BoxShadow(color: Color(0x1F102340), blurRadius: 30, offset: Offset(0, -2)),
    BoxShadow(
      color: Color(0x33102340),
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: -10,
    ),
  ];

  static const _radius = BorderRadius.all(
    Radius.circular(GlassNavTokens.radius),
  );

  @override
  Widget build(BuildContext context) {
    assert(items.isNotEmpty, 'TwBottomNavBar requiere al menos un ítem');

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: _radius,
          boxShadow: _shadow,
        ),
        child: ClipRRect(
          borderRadius: _radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
            child: ColoredBox(
              color: TwColors.surface.withValues(alpha: _fillAlpha),
              child: SizedBox(
                height: GlassNavTokens.height,
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: _TwNavItem(
                          item: items[i],
                          selected: i == selectedIndex,
                          onTap: () => onItemSelected(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rail izquierdo de escritorio: mismo ítem que la navbar móvil, sin vidrio
/// flotante, del color del contenedor para calzar con el marco de Windows.
class TwSideNavRail extends StatelessWidget {
  const TwSideNavRail({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<TwNavItemData> items;

  @override
  Widget build(BuildContext context) {
    assert(items.isNotEmpty, 'TwSideNavRail requiere al menos un ítem');

    return Material(
      color: TwColors.bg,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: TwColors.border07, width: 1)),
        ),
        child: SizedBox(
          width: GlassNavTokens.sideRailWidth,
          child: Padding(
            padding: GlassNavTokens.sideRailPadding,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const _SideNavSeparator(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _TwNavItem(
                      item: items[i],
                      selected: i == selectedIndex,
                      onTap: () => onItemSelected(i),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SideNavSeparator extends StatelessWidget {
  const _SideNavSeparator();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: GlassNavTokens.sideRailSeparatorHeight,
      thickness: 1,
      indent: GlassNavTokens.sideRailSeparatorIndent,
      endIndent: GlassNavTokens.sideRailSeparatorIndent,
      color: TwColors.border07,
    );
  }
}

class _TwNavItem extends StatelessWidget {
  const _TwNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final TwNavItemData item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.97,
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: selected ? 1 : 0),
            duration: GlassNavTokens.transitionDuration,
            curve: GlassNavTokens.transitionCurve,
            builder: (context, t, _) {
              final fg = Color.lerp(TwColors.muted, TwColors.hero700, t)!;
              final chip = Color.lerp(
                TwColors.blueTint.withValues(alpha: 0),
                TwColors.blueTint,
                t,
              )!;
              final ring = Color.lerp(
                TwColors.hero700.withValues(alpha: 0),
                TwColors.hero700,
                t,
              )!;

              return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: chip,
                      borderRadius: const BorderRadius.all(Radius.circular(15)),
                      border: Border.all(color: ring, width: 1.5),
                    ),
                    child: Icon(item.icon, size: 20, fill: t, color: fg),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TwText.navLabel.copyWith(color: fg),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
