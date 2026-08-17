import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/tw_tokens.dart';
import 'pressable.dart';

/// Botón de campana 40×40 con punto de no leídas (home).
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
    final badge = noLeidas > 0;

    return Pressable(
      scale: 0.92,
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: TwColors.surface,
                borderRadius: TwRadii.iconLg,
                border: Border.fromBorderSide(
                  BorderSide(color: TwColors.border08),
                ),
                boxShadow: TwShadows.soft,
              ),
              child: const Icon(
                Symbols.notifications_rounded,
                color: TwColors.iconInk,
                size: 20,
              ),
            ),
            if (badge)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: TwColors.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
