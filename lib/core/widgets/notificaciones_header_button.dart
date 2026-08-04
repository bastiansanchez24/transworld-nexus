import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import 'pressable.dart';

/// Botón circular de campana con badge de no leídas (home / externo).
class NotificacionesHeaderButton extends StatelessWidget {
  const NotificacionesHeaderButton({
    super.key,
    required this.noLeidas,
    required this.onTap,
    this.light = true,
  });

  final int noLeidas;
  final VoidCallback onTap;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final badge = noLeidas > 0;

    return Pressable(
      scale: 0.92,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: light
                  ? Colors.white.withValues(alpha: 0.14)
                  : AppColors.surface,
              shape: BoxShape.circle,
              border: light ? null : Border.all(color: AppColors.border),
            ),
            child: Icon(
              Symbols.notifications_rounded,
              color: light ? Colors.white : AppColors.ink,
              size: 20,
            ),
          ),
          if (badge)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: light ? Colors.white : AppColors.background,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  noLeidas > 99 ? '99+' : '$noLeidas',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
