import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Bloquea toques extra mientras una acción de navegación (o un async largo)
/// está en curso. Sin spinner: un [AbsorbPointer] transparente cubre la app.
class ActionLock extends ChangeNotifier {
  ActionLock._();

  static final ActionLock instance = ActionLock._();

  bool _locked = false;
  bool _deferred = false;
  bool _sawNav = false;
  Timer? _timeout;

  bool get isLocked => _locked;

  /// [notifyListeners] durante build/layout tira el framework (el observer
  /// de GoRouter avisa `didPush` mientras un [LayoutBuilder] está midiendo).
  void _notify() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  bool tryLock() {
    if (_locked) return false;
    _locked = true;
    _deferred = false;
    _sawNav = false;
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 8), unlock);
    _notify();
    return true;
  }

  /// El callback va a navegar o terminar más tarde: no soltar en el siguiente
  /// frame.
  void deferUnlock() {
    _deferred = true;
  }

  void unlock() {
    if (!_locked) return;
    _timeout?.cancel();
    _timeout = null;
    _locked = false;
    _deferred = false;
    _sawNav = false;
    _notify();
  }

  /// Lo llama el [NavigatorObserver] al empujar o reemplazar una ruta.
  void onNavigatorChange() {
    if (!_locked) return;
    _sawNav = true;
    unlock();
  }

  void finishIfNoNav() {
    if (_locked && !_sawNav) unlock();
  }

  void run(VoidCallback fn) {
    if (!tryLock()) return;
    try {
      fn();
    } catch (_) {
      unlock();
      rethrow;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_locked) return;
      if (!_deferred && !_sawNav) unlock();
    });
  }

  Future<void> runAsync(Future<void> Function() fn) async {
    if (!tryLock()) return;
    _deferred = true;
    try {
      await fn();
    } finally {
      if (!_sawNav) unlock();
    }
  }
}

class ActionLockObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    ActionLock.instance.onNavigatorChange();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    ActionLock.instance.onNavigatorChange();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    ActionLock.instance.unlock();
  }
}

/// Cubre la app mientras [ActionLock] está activo.
class ActionLockBarrier extends StatelessWidget {
  const ActionLockBarrier({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ActionLock.instance,
      builder: (context, _) {
        return Stack(
          children: [
            child,
            if (ActionLock.instance.isLocked)
              const Positioned.fill(
                child: AbsorbPointer(child: SizedBox.expand()),
              ),
          ],
        );
      },
    );
  }
}
