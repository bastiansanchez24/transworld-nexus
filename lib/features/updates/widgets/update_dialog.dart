import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../services/update_service.dart';

/// Barra de progreso + porcentaje para la descarga OTA.
class UpdateProgressView extends StatelessWidget {
  const UpdateProgressView({
    super.key,
    required this.progress,
    this.label,
  });

  final double progress;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).clamp(0, 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: LinearProgressIndicator(
            value: progress > 0 ? progress : null,
            minHeight: 8,
            backgroundColor: AppColors.tintNavy,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label ?? 'Descargando… $pct%',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Diálogo moderno de actualización (soft / force).
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({
    super.key,
    required this.state,
    required this.onUpdate,
    required this.onLater,
    required this.onCancelDownload,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final UpdateState state;
  final VoidCallback onUpdate;
  final VoidCallback onLater;
  final VoidCallback onCancelDownload;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final info = state.info;
    final forced = info?.isForced ?? false;
    final downloading = state.status == UpdateStatus.downloading;
    final verifying = state.status == UpdateStatus.verifying;
    final installing = state.status == UpdateStatus.installing;
    final failed = state.status == UpdateStatus.failed;
    final busy = downloading || verifying || installing;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.tintNavy,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.system_update_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              info?.releaseName ?? 'Nueva versión disponible',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (info != null) ...[
              Text(
                'v${info.installedVersion} → v${info.remoteVersion}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (forced)
                    const _MetaChip(
                      label: 'Obligatoria',
                      color: AppColors.danger,
                      bg: AppColors.dangerTint,
                    ),
                  _MetaChip(
                    label: info.formattedSize,
                    color: AppColors.textSecondary,
                    bg: AppColors.background,
                  ),
                ],
              ),
              if (info.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: Text(
                      info.notes,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
            if (busy) ...[
              const SizedBox(height: 16),
              UpdateProgressView(
                progress: verifying || installing ? 1 : state.progress,
                label: verifying
                    ? 'Verificando integridad…'
                    : installing
                        ? 'Abriendo instalador…'
                        : null,
              ),
            ],
            if (failed && state.errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerTint,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  state.errorMessage!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (busy && downloading && !forced)
          TextButton(
            onPressed: onCancelDownload,
            child: const Text('Cancelar'),
          ),
        if (!busy && !forced)
          TextButton(
            onPressed: onLater,
            child: const Text('Más tarde'),
          ),
        if (failed && state.needsInstallPermission)
          TextButton(
            onPressed: onOpenSettings,
            child: const Text('Abrir ajustes'),
          ),
        if (failed)
          FilledButton(
            onPressed: onRetry,
            child: Text(
              state.needsInstallPermission ? 'Reintentar instalación' : 'Reintentar',
            ),
          )
        else if (!busy)
          FilledButton(
            onPressed: onUpdate,
            child: const Text('Actualizar'),
          ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.color,
    required this.bg,
  });

  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
