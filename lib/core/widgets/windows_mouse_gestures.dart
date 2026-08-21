import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/refresh_on_visible.dart';

/// True en Windows nativo: el mouse tiene que poder volver atrás.
bool windowsOwnsMouseGestures({bool? isWeb, TargetPlatform? platform}) {
  if (isWeb ?? kIsWeb) return false;
  return (platform ?? defaultTargetPlatform) == TargetPlatform.windows;
}

/// Navegación de mouse de Windows: botón atrás (X1).
///
/// En iOS el pop interactivo vive en [CupertinoPage]. Windows no instala un
/// detector para X1, por lo que la aplicación lo conecta aquí con GoRouter.
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

  @override
  Widget build(BuildContext context) {
    if (!windowsOwnsMouseGestures()) return child;

    return Listener(
      onPointerDown: (event) {
        if (event.buttons & kBackMouseButton != 0) {
          _popIfPossible();
        }
      },
      child: child,
    );
  }

  void _popIfPossible() {
    // `routeInformationProvider.value.uri` no refleja los push imperativos
    // (`RouteMatchList.uri` los ignora): estando en `/eventos/:id/usar`
    // devolvía `/eventos` y esta rama nunca se cumplía.
    final location = locationOfRouter(router) ?? '';
    if (eventRouteUsesDirectMouseBack(location) && router.canPop()) {
      // Estas pantallas no tienen confirmación de cambios. El pop directo
      // evita que el maybePop termine consultando al PopScope del shell que
      // está debajo y revierta visualmente la transición.
      router.pop();
      return;
    }
    router.routerDelegate.navigatorKey.currentState?.maybePop();
  }
}

/// Los dos hubs abiertos desde la lista no tienen estado sin guardar y deben
/// consumir exactamente un clic X1. El match por segmentos evita afectar
/// formularios o cualquier otra navegación de la aplicación.
bool eventRouteUsesDirectMouseBack(String location) {
  final segments = Uri.parse(location).pathSegments;
  return segments.length == 3 &&
      segments[0] == 'eventos' &&
      segments[1].isNotEmpty &&
      (segments[2] == 'usar' || segments[2] == 'acceso');
}
