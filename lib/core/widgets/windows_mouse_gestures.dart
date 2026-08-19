import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// True en Windows nativo: el mouse tiene que poder volver atrás.
bool windowsOwnsMouseGestures({bool? isWeb, TargetPlatform? platform}) {
  if (isWeb ?? kIsWeb) return false;
  return (platform ?? defaultTargetPlatform) == TargetPlatform.windows;
}

/// Gestos de mouse de Windows: botón atrás (X1) y deslizar desde el borde.
///
/// En iOS el pop interactivo vive en [CupertinoPage]. En Windows las rutas
/// push son SharedAxis y el motor no instala ningún detector, así que el
/// clic-arrastrar y el botón lateral del mouse no hacían nada.
///
/// [router] se pasa desde el `builder` de [MaterialApp.router]: ese context
/// está *encima* del [InheritedGoRouter] y `GoRouter.of` no lo encuentra.
class WindowsMouseGestures extends StatelessWidget {
  const WindowsMouseGestures({
    super.key,
    required this.child,
    required this.router,
  });

  final Widget child;
  final GoRouter router;

  /// Ancho del borde izquierdo donde el arrastre cuenta como "atrás".
  /// Más ancho que los 20 px de iOS: con mouse hay que acertar el borde.
  static const edgeWidth = 64.0;

  static const commitDistance = 80.0;
  static const flingVelocity = 400.0;

  @override
  Widget build(BuildContext context) {
    if (!windowsOwnsMouseGestures()) return child;

    return Listener(
      onPointerDown: (event) {
        if (event.buttons & kBackMouseButton != 0) {
          _popIfPossible();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: edgeWidth,
            child: _EdgeBackSwipe(onCommit: _popIfPossible),
          ),
        ],
      ),
    );
  }

  void _popIfPossible() {
    if (router.canPop()) router.pop();
  }
}

class _EdgeBackSwipe extends StatefulWidget {
  const _EdgeBackSwipe({required this.onCommit});

  final VoidCallback onCommit;

  @override
  State<_EdgeBackSwipe> createState() => _EdgeBackSwipeState();
}

class _EdgeBackSwipeState extends State<_EdgeBackSwipe> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _dx = 0,
      onHorizontalDragUpdate: (details) {
        _dx += details.primaryDelta ?? 0;
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (_dx >= WindowsMouseGestures.commitDistance ||
            velocity >= WindowsMouseGestures.flingVelocity) {
          widget.onCommit();
        }
      },
    );
  }
}
