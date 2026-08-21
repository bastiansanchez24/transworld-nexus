import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/tw_tokens.dart';

/// Indicador de carga de una imagen: un bloque con un brillo que barre.
///
/// Ocupa todo el espacio del padre, así que en un avatar recortado con
/// `ClipOval` sale circular sin tener que decírselo.
///
/// Todos los esqueletos vivos comparten **un solo** [Ticker]: una lista de
/// doscientos leads con foto no puede levantar doscientos
/// `AnimationController`, y además así el brillo va sincronizado entre
/// tarjetas en vez de parpadear cada una por su lado.
class AppImageSkeleton extends StatelessWidget {
  const AppImageSkeleton({super.key, this.radio});

  /// Redondeo propio. Se omite cuando el padre ya recorta (avatares, portadas).
  final BorderRadius? radio;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _relojShimmer,
      builder: (context, _) {
        // -1 → 2: la banda de brillo entra por la izquierda y sale por la
        // derecha, con una pausa natural entre pasadas.
        final x = -1.0 + 3.0 * _relojShimmer.progreso;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radio,
            gradient: LinearGradient(
              begin: Alignment(x - 1, -0.6),
              end: Alignment(x + 1, 0.6),
              colors: const [_base, _brillo, _base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }

  static const _base = TwColors.surfaceTint;
  static const _brillo = Color(0xFFF3F6FB);
}

const _periodo = Duration(milliseconds: 1400);

final _relojShimmer = _RelojShimmer();

/// Reloj compartido por todos los [AppImageSkeleton] montados.
///
/// El [Ticker] solo corre mientras hay al menos un esqueleto escuchando: sin
/// fotos cargando no se pide un solo frame de más.
class _RelojShimmer extends ChangeNotifier {
  _RelojShimmer() {
    _ticker = Ticker(_alLatir);
  }

  late final Ticker _ticker;
  double _progreso = 0;

  /// Posición del brillo dentro del ciclo, de 0 a 1.
  double get progreso => _progreso;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (!_ticker.isActive) _ticker.start();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners && _ticker.isActive) {
      _ticker.stop();
      _progreso = 0;
    }
  }

  void _alLatir(Duration transcurrido) {
    _progreso =
        (transcurrido.inMilliseconds % _periodo.inMilliseconds) /
        _periodo.inMilliseconds;
    notifyListeners();
  }
}
