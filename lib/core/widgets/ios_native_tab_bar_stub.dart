import 'package:flutter/material.dart';

import 'tw_bottom_nav_bar.dart';

/// Stub de web: no hay UIKit. [MainShellNavHost] no monta este widget ahí.
class CNTabBarRouteObserver extends NavigatorObserver {
  CNTabBarRouteObserver();
}

/// Stub de web: sin UIKit no hay nada a quien avisar de la transición.
NavigatorObserver crearCNTransitionObserver() => NavigatorObserver();

/// Contenedor de la tab bar nativa iOS. En web no se llega a construir.
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
  Widget build(BuildContext context) => const SizedBox.shrink();
}
