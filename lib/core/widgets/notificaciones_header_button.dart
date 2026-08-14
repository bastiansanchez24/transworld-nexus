import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
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
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Symbols.notifications_rounded,
                color: AppColors.identityAccent,
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
                    color: AppColors.danger,
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
