import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pressable.dart';

/// Botón compacto para abrir la gestión de acceso de un evento.
class EventoAccesoButton extends StatelessWidget {
  const EventoAccesoButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Gestionar acceso',
      child: Pressable(
        scale: 0.92,
        onTap: onTap,
        child: Semantics(
          button: true,
          label: 'Gestionar acceso',
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tintNavy,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Symbols.group_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
