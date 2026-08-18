import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/offline/sync_queue_service.dart';
import '../../data/offline/sync_coordinator.dart';
import '../network/connectivity_service.dart';
import '../theme/app_theme.dart';
import 'sync_conflict_listener.dart';

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
    final conflicts = ref.watch(syncConflictsProvider).length;

    if (isOnline && pending == 0 && conflicts == 0) {
      return const SizedBox.shrink();
    }

    final texto = conflicts > 0
        ? '$conflicts conflicto(s) de sincronización · Revisar'
        : !isOnline
        ? (pending > 0
              ? 'Sin conexión · $pending pendiente(s)'
              : 'Sin conexión')
        : '$pending pendiente(s) · Reintentar';

    return Material(
      color: conflicts > 0
          ? AppColors.dangerTint
          : !isOnline
          ? AppColors.dangerTint
          : AppColors.successTint,
      child: InkWell(
        onTap: conflicts > 0
            ? () => showSyncConflictsSheet(context, ref)
            : isOnline && pending > 0
            ? () => ref.read(syncCoordinatorProvider).sincronizarAhora()
            : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                conflicts > 0
                    ? Icons.warning_amber_rounded
                    : !isOnline
                    ? Icons.cloud_off_rounded
                    : Icons.cloud_upload_rounded,
                size: 16,
                color: conflicts > 0 || !isOnline
                    ? AppColors.danger
                    : AppColors.success,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  texto,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: conflicts > 0 || !isOnline
                        ? AppColors.danger
                        : AppColors.primaryDeep,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
