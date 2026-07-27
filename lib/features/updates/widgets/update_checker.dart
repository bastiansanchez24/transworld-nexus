import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/update_providers.dart';
import '../services/update_service.dart';
import 'update_dialog.dart';

/// Dispara el check OTA al montarse (post-login) y muestra el diálogo
/// cuando hay una actualización disponible.
///
/// Debe vivir bajo una ruta autenticada (p. ej. [HomeScreen]).
class UpdateChecker extends ConsumerStatefulWidget {
  const UpdateChecker({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends ConsumerState<UpdateChecker> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _started) return;
      _started = true;
      ref.read(updateControllerProvider.notifier).checkOnLaunch();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UpdateState>(updateControllerProvider, (prev, next) {
      final becameAvailable = next.status == UpdateStatus.available &&
          prev?.status != UpdateStatus.available;
      final controller = ref.read(updateControllerProvider.notifier);

      if (becameAvailable && !controller.isDialogVisible) {
        _showDialog(context);
        return;
      }

      // Actualizar diálogo vivo durante download/fail (mismo route).
      if (controller.isDialogVisible &&
          (next.status == UpdateStatus.downloading ||
              next.status == UpdateStatus.verifying ||
              next.status == UpdateStatus.installing ||
              next.status == UpdateStatus.failed ||
              next.status == UpdateStatus.available)) {
        // El diálogo es Stateful vía showDialog estático; se cierra/reabre
        // sería brusco. Usamos un overlay con estado externo:
        // en la práctica cerramos y reabrimos solo en failed→retry flows
        // no; mejor un diálogo que escucha el provider.
      }
    });

    return widget.child;
  }

  Future<void> _showDialog(BuildContext context) async {
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
                onLater: () {
                  ref.read(updateControllerProvider.notifier).dismiss();
                  Navigator.of(dialogContext).pop();
                },
                onCancelDownload: () {
                  ref.read(updateControllerProvider.notifier).cancelDownload();
                },
                onRetry: () {
                  final s = ref.read(updateControllerProvider);
                  if (s.needsInstallPermission || s.downloadedApkPath != null) {
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

    if (mounted) {
      final current = ref.read(updateControllerProvider);
      // Si force y cerró sin actualizar, reabrir en el próximo frame.
      if (current.info?.isForced == true &&
          current.status != UpdateStatus.installing) {
        controller.markDialogVisible(false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showDialog(context);
        });
      } else {
        controller.markDialogVisible(false);
        if (current.status == UpdateStatus.available) {
          controller.dismiss();
        }
      }
    }
  }
}
