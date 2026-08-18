import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';
import 'tw_bottom_nav_bar.dart';

export 'package:cupertino_native_better/cupertino_native_better.dart'
    show CNTabBarRouteObserver;

/// `UITabBar` nativo (Liquid Glass en iOS 26) pegado al borde inferior.
///
/// Sin `SafeArea`: el `UITabBar` ya reserva el home indicator por su cuenta y
/// añadirlo dos veces dejaba la barra flotando muy por encima del borde.
///
/// En tests y hosts que no son iOS ([Platform.isIOS] falso) pinta un
/// [CupertinoTabBar]: `CNTabBar` agenda un timer de platform views que
/// rompe `flutter test` y no hay UIKit que hospedar.
class IosNativeTabBar extends StatelessWidget {
  const IosNativeTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.tint,
  });

  final List<TwNavItemData> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    assert(items.length >= 2, 'IosNativeTabBar requiere al menos dos ítems');

    final accent = tint ?? AppColors.primary;

    if (!Platform.isIOS) {
      return SafeArea(
        top: false,
        child: CupertinoTabBar(
          items: [
            for (final item in items)
              BottomNavigationBarItem(icon: Icon(item.icon), label: item.label),
          ],
          currentIndex: currentIndex,
          onTap: onTap,
          activeColor: accent,
        ),
      );
    }

    return CNTabBar(
      items: [
        for (final item in items)
          CNTabBarItem(
            label: item.label,
            icon: CNSymbol(item.sfSymbol),
            activeIcon: CNSymbol(item.sfSymbolActive ?? item.sfSymbol),
          ),
      ],
      currentIndex: currentIndex,
      onTap: onTap,
      tint: accent,
      iconSize: GlassNavTokens.nativeIosIconSize,
    );
  }
}
