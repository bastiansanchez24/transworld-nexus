import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/evento.dart';

class ProximoEventoCard extends StatelessWidget {
  const ProximoEventoCard({super.key, required this.evento});

  final Evento evento;

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat('EEEE d MMM', 'es').format(evento.fecha);
    final lugar = evento.lugar ?? evento.pais ?? '';

    return Pressable(
      onTap: () => context.push(RoutePaths.usarEvento(evento.id)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(AppRadius.fab),
          boxShadow: AppColors.shadowHero,
        ),
        child: Row(
          children: [
            DateTile(date: evento.fecha, hero: true),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _PulseDot(),
                      const SizedBox(width: 6),
                      Text(
                        'PRÓXIMO EVENTO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    evento.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [fecha, if (lugar.isNotEmpty) lugar].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Symbols.chevron_right_rounded,
              color: AppColors.chevronMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) {
      return Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
      );
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = (_ctrl.value < 0.5)
            ? (_ctrl.value * 2)
            : (1 - (_ctrl.value - 0.5) * 2);
        final scale = 1 + 0.5 * t;
        final opacity = 1 - 0.5 * t;
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: child,
          ),
        );
      },
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
