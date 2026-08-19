import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Arrastre con mouse y trackpad, no solo con el dedo.
///
/// Flutter, por defecto, reserva el drag a touch/stylus: en Windows las
/// listas, el carrusel del home y cualquier [PageView] no responden al
/// clic-arrastrar. Esta es la única alternativa al swipe táctil en escritorio.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
