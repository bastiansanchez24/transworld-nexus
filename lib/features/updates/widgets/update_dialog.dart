import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/auth_repository.dart';
import '../providers/update_providers.dart';
import '../services/update_platform.dart';
import '../services/update_service.dart';

/// Barra de progreso + porcentaje para la descarga OTA.
class UpdateProgressView extends StatelessWidget {
  const UpdateProgressView({super.key, required this.progress, this.label});

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
    final installingLabel = otaInstallingLabel;

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
                    ? installingLabel
                    : null,
              ),
            ],
            if (failed && state.needsInstallPermission) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.tintNavy,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.settings_applications_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.errorMessage ??
                            'Para actualizar RegisPro debes permitir la instalación '
                                'de aplicaciones. Actívalo en Configuración y '
                                'vuelve a intentar.',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (failed && state.errorMessage != null) ...[
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
          TextButton(onPressed: onLater, child: const Text('Más tarde')),
        if (failed && state.needsInstallPermission)
          OutlinedButton(
            onPressed: onOpenSettings,
            child: const Text('Configuración'),
          ),
        if (failed)
          FilledButton(onPressed: onRetry, child: const Text('Reintentar'))
        else if (!busy)
          FilledButton(onPressed: onUpdate, child: const Text('Actualizar')),
      ],
    );
  }
}

/// Muestra el diálogo OTA compartido (UpdateChecker, Actualizaciones, etc.).
///
/// Centraliza el cierre para evitar rutas duplicadas: el flag
/// [UpdateController.isDialogVisible] solo se limpia al terminar [showDialog],
/// y [UpdateController.dismiss] se llama una sola vez al cerrar sin instalar.
Future<void> showAppUpdateDialog(BuildContext context, WidgetRef ref) async {
  // Nunca mostrar el modal sin sesión (login/splash/público).
  if (ref.read(authRepositoryProvider).currentSession == null) return;

  final controller = ref.read(updateControllerProvider.notifier);
  if (controller.isDialogVisible) return;
  controller.markDialogVisible(true);

  await showDialog<void>(
    context: context,
    barrierDismissible:
        !(ref.read(updateControllerProvider).info?.isForced ?? false),
    builder: (dialogContext) {
      return Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(updateControllerProvider);
          final forced = state.info?.isForced ?? false;
          return PopScope(
            canPop: !forced,
            child: UpdateDialog(
              state: state,
              onUpdate: () {
                ref
                    .read(updateControllerProvider.notifier)
                    .downloadAndInstall();
              },
              onLater: () => Navigator.of(dialogContext).pop(),
              onCancelDownload: () {
                ref.read(updateControllerProvider.notifier).cancelDownload();
              },
              onRetry: () {
                final s = ref.read(updateControllerProvider);
                if (s.needsInstallPermission || s.downloadedFilePath != null) {
                  ref.read(updateControllerProvider.notifier).retryInstall();
                } else {
                  ref
                      .read(updateControllerProvider.notifier)
                      .downloadAndInstall();
                }
              },
              onOpenSettings: () {
                ref
                    .read(updateControllerProvider.notifier)
                    .openInstallSettings();
              },
            ),
          );
        },
      );
    },
  );

  if (!context.mounted) return;

  final current = ref.read(updateControllerProvider);
  controller.markDialogVisible(false);

  if (current.info?.isForced == true &&
      current.status != UpdateStatus.installing) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) showAppUpdateDialog(context, ref);
    });
    return;
  }

  if (current.info != null && current.status != UpdateStatus.installing) {
    controller.dismiss();
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color, required this.bg});

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
