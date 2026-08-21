import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Instala el corrector únicamente en iOS nativo.
///
/// En Android devuelve exactamente [child], sin agregar un elemento con estado
/// ni escuchar la animación de la ruta. Así el botón Atrás queda completamente
/// a cargo del Router/Navigator de Android.
Widget iosBackSwipeGuard({
  required Widget child,
  bool? isWeb,
  TargetPlatform? platform,
}) {
  final enabled =
      !(isWeb ?? kIsWeb) &&
      (platform ?? defaultTargetPlatform) == TargetPlatform.iOS;
  return enabled ? IosBackSwipeCommitter(child: child) : child;
}

/// Confirma un pop Cupertino que ya cruzó la mitad de la pantalla.
///
/// Flutter prioriza la velocidad del último instante sobre la distancia. En un
/// iPhone de alta tasa de refresco, un movimiento inverso mínimo justo al soltar
/// puede iniciar el rebote aun cuando la ruta está casi fuera. Este guard se
/// limita a iOS nativo y solo interviene en ese caso: gesto interactivo visto,
/// animación intentando volver hacia delante y progreso ya bajo el umbral.
class IosBackSwipeCommitter extends StatefulWidget {
  const IosBackSwipeCommitter({super.key, required this.child});

  final Widget child;

  @override
  State<IosBackSwipeCommitter> createState() => _IosBackSwipeCommitterState();
}

class _IosBackSwipeCommitterState extends State<IosBackSwipeCommitter> {
  Animation<double>? _routeAnimation;
  bool _commitScheduled = false;
  double _lastValue = 1;
  double _furthestValue = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = ModalRoute.of(context)?.animation;
    if (identical(next, _routeAnimation)) return;
    _routeAnimation?.removeListener(_onAnimationTick);
    _routeAnimation = next;
    _lastValue = next?.value ?? 1;
    _furthestValue = _lastValue;
    _routeAnimation?.addListener(_onAnimationTick);
  }

  @override
  void dispose() {
    _routeAnimation?.removeListener(_onAnimationTick);
    _routeAnimation = null;
    super.dispose();
  }

  void _onAnimationTick() {
    if (!mounted) return;
    final navigator = Navigator.maybeOf(context);
    final animation = _routeAnimation;
    if (navigator == null || animation == null) return;

    final value = animation.value;
    if (!navigator.userGestureInProgress) {
      _lastValue = value;
      _furthestValue = value;
      return;
    }

    if (value < _furthestValue) _furthestValue = value;
    final shouldCommit =
        animation.isAnimating &&
        value > _lastValue &&
        _furthestValue <= 0.5 &&
        value <= 0.5;
    _lastValue = value;

    if (!shouldCommit || _commitScheduled) return;
    _commitScheduled = true;
    scheduleMicrotask(() {
      _commitScheduled = false;
      if (!mounted) return;
      final route = ModalRoute.of(context);
      final currentAnimation = _routeAnimation;
      final currentNavigator = Navigator.maybeOf(context);
      if (route?.isCurrent != true ||
          currentNavigator == null ||
          !currentNavigator.userGestureInProgress ||
          currentAnimation == null ||
          currentAnimation.value > 0.5) {
        return;
      }
      currentNavigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
