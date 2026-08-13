import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable.dart';

class GlassNavItemData {
  const GlassNavItemData({
    required this.icon,
    this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData? activeIcon;
  final String label;
}

/// Bottom navbar flotante estilo Liquid Glass.
///
/// La navegación real queda fuera: este widget solo pinta y reporta el índice.
class GlassBottomNavBar extends StatelessWidget {
  const GlassBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<GlassNavItemData> items;

  @override
  Widget build(BuildContext context) {
    assert(items.isNotEmpty, 'GlassBottomNavBar requiere al menos un ítem');
    final brightness = Theme.of(context).brightness;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GlassNavTokens.radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: GlassNavTokens.blurSigma,
            sigmaY: GlassNavTokens.blurSigma,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GlassNavTokens.radius),
              color: GlassNavTokens.glassTint(brightness),
              border: Border.all(
                color: GlassNavTokens.borderColor(brightness),
                width: 0.5,
              ),
            ),
            child: SizedBox(
              height: GlassNavTokens.height,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: GlassNavTokens.innerPaddingH,
                  vertical: GlassNavTokens.innerPaddingV,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: _GlassNavItem(
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

class _GlassNavItem extends StatelessWidget {
  const _GlassNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final GlassNavItemData item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final active = GlassNavTokens.activeColor(brightness);
    final inactive = GlassNavTokens.inactiveColor(brightness);

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
              final color = Color.lerp(inactive, active, t)!;
              final icon = t > 0.5 ? (item.activeIcon ?? item.icon) : item.icon;
              final outline = Color.lerp(
                active.withValues(alpha: 0),
                active,
                t,
              )!;
              return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: outline, width: 1.25),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Icon(
                        icon,
                        size: GlassNavTokens.iconSize,
                        fill: t,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: GlassNavTokens.iconLabelGap),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color,
                      height: 1.1,
                    ),
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
