import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pressable.dart';

/// Card expandible local al módulo de perfil (header + cuerpo animado).
class PerfilExpandableSection extends StatelessWidget {
  const PerfilExpandableSection({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.shadowRest,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Pressable(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.tintNavy,
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: AppMotion.toggle,
                    curve: AppMotion.ease,
                    child: const Icon(
                      Symbols.expand_more_rounded,
                      color: AppColors.chevronMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.toggle,
            curve: AppMotion.ease,
            alignment: Alignment.topCenter,
            child: expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(height: 1, color: AppColors.divider),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                        child: child,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
