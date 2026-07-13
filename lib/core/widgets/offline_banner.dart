import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/offline/sync_queue_service.dart';
import '../network/connectivity_service.dart';
import '../theme/app_theme.dart';

/// Indicador visible de "modo local" + cantidad de operaciones pendientes
/// por sincronizar. En el proyecto legado este indicador vivía copiado y
/// levemente distinto en cada pantalla; acá es un solo widget reutilizable
/// que además refleja el estado real de la cola unificada (ver
/// data/offline/sync_queue_service.dart).
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final pending = ref.watch(pendingSyncCountProvider);

    if (isOnline && pending == 0) return const SizedBox.shrink();

    final texto = !isOnline
        ? (pending > 0 ? 'Sin conexión · $pending pendiente(s)' : 'Sin conexión')
        : 'Sincronizando $pending pendiente(s)...';

    return Container(
      width: double.infinity,
      color: !isOnline ? AppColors.error.withValues(alpha: 0.12) : AppColors.accent.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            !isOnline ? Icons.cloud_off_rounded : Icons.sync_rounded,
            size: 16,
            color: !isOnline ? AppColors.error : AppColors.primaryDark,
          ),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: !isOnline ? AppColors.error : AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
