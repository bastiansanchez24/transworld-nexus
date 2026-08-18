import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/auth_repository.dart';
import '../providers/update_providers.dart';
import '../services/update_service.dart';
import 'update_dialog.dart';

/// Dispara el check OTA al montarse (post-login) y al volver del segundo
/// plano, y muestra el diálogo cuando hay una actualización disponible.
///
/// Debe vivir bajo una ruta autenticada (p. ej. [HomeScreen]).
/// El modal solo se muestra con sesión activa.
class UpdateChecker extends ConsumerStatefulWidget {
  const UpdateChecker({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends ConsumerState<UpdateChecker>
    with WidgetsBindingObserver {
  bool _started = false;
  bool _wasBackgrounded = false;

  bool get _isLoggedIn =>
      ref.read(authRepositoryProvider).currentSession != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _started) return;
      _started = true;
      if (!_isLoggedIn) return;
      ref.read(updateControllerProvider.notifier).checkOnLaunch();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _wasBackgrounded = true;
      case AppLifecycleState.inactive:
        // Transición típica al salir/entrar; no dispara check.
        break;
      case AppLifecycleState.resumed:
        if (!_wasBackgrounded || !mounted || !_isLoggedIn) return;
        _wasBackgrounded = false;
        ref.read(updateControllerProvider.notifier).checkOnResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UpdateState>(updateControllerProvider, (prev, next) {
      if (!_isLoggedIn) return;

      final becameAvailable = next.status == UpdateStatus.available &&
          prev?.status != UpdateStatus.available;
      final controller = ref.read(updateControllerProvider.notifier);

      if (becameAvailable && !controller.isDialogVisible) {
        showAppUpdateDialog(context, ref);
      }
    });

    return widget.child;
  }
}
