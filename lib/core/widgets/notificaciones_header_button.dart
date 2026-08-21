import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'ios_native_chrome.dart';

/// Botón de campana 40×40 con insignia numérica de no leídas (home).
class NotificacionesHeaderButton extends StatelessWidget {
  const NotificacionesHeaderButton({
    super.key,
    required this.noLeidas,
    required this.onTap,
  });

  final int noLeidas;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TwIosGlassIconButton(
      icon: Symbols.notifications_rounded,
      tooltip: 'Notificaciones',
      onTap: onTap,
      size: 40,
      iconSize: 20,
      sfSymbol: 'bell',
      badgeCount: noLeidas > 0 ? noLeidas : null,
    );
  }
}
