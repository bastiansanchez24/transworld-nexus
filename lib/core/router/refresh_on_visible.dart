import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'browser_history.dart';

/// True en la transición de no-visible → visible, para recargar una lista
/// al abrirla (menú, tab o al volver de editar) y no al montar el evento.
bool justBecameVisible({
  required bool wasVisible,
  required String? currentLocation,
  required String targetLocation,
}) {
  final visible = currentLocation == null || currentLocation == targetLocation;
  return visible && !wasVisible;
}

String? currentLocationOf(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router == null) return null;
  return locationOfRouter(router);
}

/// Ubicación actual: la última coincidencia de la pila del `routerDelegate`.
///
/// Ni `routeInformationProvider.value` ni `currentConfiguration.uri` sirven
/// aquí. Un `push` imperativo deja el provider en la ruta base (el `Router`
/// le reporta de vuelta la configuración parseada) y `uri` tampoco cambia:
/// con `/lista` abierta y `/detalle` empujada encima, ambos siguen diciendo
/// `/lista`. La ruta de arriba solo aparece en `matches.last`.
String? locationOfRouter(GoRouter router) {
  final pila = matchedLocationsInStack(
    router.routerDelegate.currentConfiguration,
  );
  if (pila.isEmpty) return router.routeInformationProvider.value.uri.path;
  return _pathOf(pila.last);
}

/// Vuelve una pantalla atrás dejando el historial del navegador alineado con
/// la pila de la app.
///
/// go_router reporta cada cambio del delegate al motor, y en web eso es un
/// `pushState`: un `pop` normal **añadía** una entrada en vez de consumir la
/// que creó el `push`. Así el historial crecía con cada ida y vuelta y el
/// atrás del navegador —o el botón lateral del mouse— había que pulsarlo
/// varias veces para avanzar una sola pantalla, porque las entradas
/// intermedias repetían el mismo estado.
///
/// Por eso en web se retrocede de verdad (`history.go(-1)`) siempre que la
/// entrada la haya creado esta sesión; el `popstate` resultante hace que
/// go_router restaure la pila anterior. Si no hay entrada propia —por ejemplo
/// tras un F5 dentro de la pila— se cae al `pop`, marcado con
/// `Router.neglect` para que al menos reemplace en vez de apilar.
///
/// Fuera de web nada de esto aplica y el `pop` es el camino normal.
void volverAtras(BuildContext context) {
  if (!context.mounted || !context.canPop()) return;
  final router = GoRouter.maybeOf(context);
  if (router != null && entradasPropiasDeHistorial(router) > 0) {
    if (retrocederEnHistorial(1)) return;
  }
  Router.neglect(context, () => context.pop());
}

/// Profundidad de pila con la que arrancó esta carga de página.
///
/// Todo lo que esté por encima lo empujó la sesión actual, y cada empujón
/// dejó su propia entrada en el historial del navegador: son las únicas que
/// un `history.go(-n)` puede consumir sin sacar al usuario del sitio. Tras un
/// F5 en mitad de la pila, go_router restaura las rutas pero el historial
/// arranca de cero, y ahí retroceder nos echaría de la aplicación.
int? _profundidadBase;

@visibleForTesting
void reiniciarBaseDeHistorial() => _profundidadBase = null;

/// Fija la base con la primera configuración real del [router].
///
/// Tiene que ser al construirlo y no de forma perezosa: si la primera medida
/// llega con el usuario ya dentro de un evento, esa profundidad se tomaría
/// por el punto de partida y nunca se retrocedería en el historial. Al
/// arrancar tras un F5 la pila restaurada sí es el punto de partida, y ahí lo
/// correcto es no tocar el historial.
void sembrarBaseDeHistorial(GoRouter router) {
  _profundidadBase = null;
  final delegate = router.routerDelegate;

  int profundidad() =>
      matchedLocationsInStack(delegate.currentConfiguration).length;

  if (profundidad() > 0) {
    _profundidadBase = profundidad();
    return;
  }

  void alPrimerConfig() {
    final actual = profundidad();
    if (actual == 0) return;
    _profundidadBase = actual;
    delegate.removeListener(alPrimerConfig);
  }

  delegate.addListener(alPrimerConfig);
}

/// Cuántas entradas de historial creó esta sesión y siguen vivas.
@visibleForTesting
int entradasPropiasDeHistorial(GoRouter router) {
  final actual = matchedLocationsInStack(
    router.routerDelegate.currentConfiguration,
  ).length;
  final base = _profundidadBase ??= actual;
  if (actual <= base) {
    // Un `go` puede dejar la pila por debajo del arranque; desde ahí las
    // entradas de la sesión ya se consumieron.
    _profundidadBase = actual;
    return 0;
  }
  return actual - base;
}

/// `push` cuyo futuro también resuelve cuando la ruta desaparece de la pila
/// sin pasar por un `pop` del `Navigator`.
///
/// El atrás del navegador no hace pop: devuelve el `RouteMatchList`
/// codificado del historial y go_router lo re-decodifica creando un
/// `Completer` nuevo para cada push imperativo (flutter/flutter#128122). El
/// futuro que devolvió `context.push` queda huérfano para siempre, y con él
/// cualquier spinner o cámara que esperara su regreso.
///
/// Aquí se corre una carrera entre ese futuro (camino normal del pop) y un
/// oyente del `routerDelegate` que detecta la salida de la pila (camino del
/// historial). Gana el primero que llegue.
Future<void> pushYEsperarSalida(
  BuildContext context,
  String location, {
  Object? extra,
}) {
  final router = GoRouter.maybeOf(context);
  if (router == null) return Future<void>.value();

  final target = _pathOf(location);
  final delegate = router.routerDelegate;
  final completer = Completer<void>();

  // Sin esto se completaría de inmediato: el `push` no llega a la
  // configuración del delegate hasta que el Router parsea la ruta nueva.
  var aparecio = false;

  void alCambiarLaPila() {
    if (completer.isCompleted) return;
    final enPila = matchedLocationsInStack(
      delegate.currentConfiguration,
    ).map(_pathOf).contains(target);
    if (!aparecio) {
      aparecio = enPila;
      return;
    }
    if (enPila) return;
    completer.complete();
  }

  // El oyente va antes del `push`: cuando no hay redirect asíncrono el Router
  // parsea y notifica dentro de la misma llamada, así que registrarlo después
  // se perdía el aviso de que la ruta ya está en la pila.
  delegate.addListener(alCambiarLaPila);
  final futuroDelPush = router.push<Object?>(location, extra: extra);
  alCambiarLaPila();
  unawaited(
    futuroDelPush.then(
      (_) {
        if (!completer.isCompleted) completer.complete();
      },
      onError: (_, _) {
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );

  return completer.future.whenComplete(
    () => delegate.removeListener(alCambiarLaPila),
  );
}

/// Vuelve a [listPath] tras guardar o borrar: `pop` si hay historial (la
/// lista quedó debajo) o `go` si se abrió el detalle sin esa pila.
void volverALista(BuildContext context, String listPath) {
  if (!context.mounted) return;
  final actual = currentLocationOf(context);
  if (actual == listPath) return;
  if (context.canPop()) {
    volverAtras(context);
    return;
  }
  context.go(listPath);
}

/// Abre [location]: si ya está más abajo en la pila, hace pop hasta ella;
/// si no, la empuja. Así el evento y su actividad no se apilan en bucle.
void abrirOVolverA(BuildContext context, String location) {
  if (!context.mounted) return;
  final router = GoRouter.maybeOf(context);
  if (router == null) return;

  final target = _pathOf(location);
  if (target.isEmpty) return;

  final stack = matchedLocationsInStack(
    router.routerDelegate.currentConfiguration,
  ).map(_pathOf).toList();
  final index = stack.indexOf(target);
  if (index >= 0) {
    final pasos = stack.length - 1 - index;
    if (pasos <= 0) return;
    // En web se retrocede de una sola vez: `history.go(-n)` deja el historial
    // alineado con la pila, de modo que el atrás del navegador siempre avanza
    // una pantalla en lugar de repetir la ida y vuelta.
    if (pasos <= entradasPropiasDeHistorial(router) &&
        retrocederEnHistorial(pasos)) {
      return;
    }
    for (var i = 0; i < pasos; i++) {
      if (!context.canPop()) return;
      volverAtras(context);
    }
    return;
  }
  context.push(location);
}

/// Rutas hoja de la pila (sin el shell). Un `push` deja un match extra al
/// final; el tab del shell queda primero.
@visibleForTesting
List<String> matchedLocationsInStack(RouteMatchList configuration) {
  final locations = <String>[];

  void collect(List<RouteMatchBase> matches) {
    for (final match in matches) {
      if (match is ShellRouteMatch) {
        collect(match.matches);
        continue;
      }
      locations.add(match.matchedLocation);
    }
  }

  collect(configuration.matches);
  return locations;
}

String _pathOf(String location) => Uri.parse(location).path;

/// Invalida providers la primera vez que esta ruta queda al frente, y cada
/// vez que se vuelve a ella (tabs del shell, menú del evento, pop de editar).
///
/// Escucha el [RouteInformationProvider] global: el `GoRouterState` local de
/// una rama del shell no cambia al empujar una ruta hermana.
mixin RefreshOnVisible<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  String get refreshWhenLocation;

  void onBecomeVisible();

  var _visible = false;
  RouteInformationProvider? _locationProvider;
  Listenable? _routerDelegate;

  /// Animaciones de la ruta a las que estamos enganchados esperando que se
  /// asienten, si las hay.
  final List<Animation<double>> _animacionesEnEspera = <Animation<double>>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);

    final provider = router?.routeInformationProvider;
    if (!identical(provider, _locationProvider)) {
      _locationProvider?.removeListener(_onLocation);
      _locationProvider = provider;
      _locationProvider?.addListener(_onLocation);
    }

    // El `routeInformationProvider` solo notifica al navegar hacia adelante:
    // `GoRouteInformationProvider.routerReportsNewRouteInformation` asigna su
    // valor **sin** `notifyListeners`, de modo que un `pop` (botón atrás o
    // gesto iOS) no despertaba a nadie y [onBecomeVisible] nunca corría al
    // volver. El delegate sí notifica en ambos sentidos.
    final delegate = router?.routerDelegate;
    if (!identical(delegate, _routerDelegate)) {
      _routerDelegate?.removeListener(_onLocation);
      _routerDelegate = delegate;
      _routerDelegate?.addListener(_onLocation);
    }

    _syncVisibility();
  }

  @override
  void dispose() {
    _locationProvider?.removeListener(_onLocation);
    _routerDelegate?.removeListener(_onLocation);
    _soltarAnimaciones();
    super.dispose();
  }

  void _onLocation() {
    if (!mounted) return;
    _syncVisibility();
  }

  void _syncVisibility() {
    final location = currentLocationOf(context);
    final visibleNow = justBecameVisible(
      wasVisible: _visible,
      currentLocation: location,
      targetLocation: refreshWhenLocation,
    );
    _visible = location == null || location == refreshWhenLocation;
    if (!visibleNow) return;

    // Hay que salir de la fase de build antes de mirar nada: durante el primer
    // `build` de una ruta recién empujada su `animation` todavía informa
    // `completed`, y la transición solo arranca después.
    _enFaseSegura(_esperarAQueSeAsiente);
  }

  /// El aviso del delegate llega **al empezar** la transición, no al acabarla.
  /// Invalidar ahí reconstruye el árbol mientras la página se desliza, que es
  /// lo que se sentía como tirones en el gesto de volver de iOS.
  ///
  /// Se espera a las dos animaciones de la ruta: [ModalRoute.animation] cubre
  /// el push de esta pantalla y [ModalRoute.secondaryAnimation] el pop de la
  /// que estaba encima —al volver, la de abajo nunca mueve su `animation`.
  void _esperarAQueSeAsiente() {
    if (!mounted) return;
    _soltarAnimaciones();

    final route = ModalRoute.of(context);
    final animaciones = <Animation<double>>[
      if (route?.animation != null) route!.animation!,
      if (route?.secondaryAnimation != null) route!.secondaryAnimation!,
    ];

    if (!animaciones.any(_estaAnimando)) {
      onBecomeVisible();
      return;
    }

    void oyente(AnimationStatus _) {
      if (_animacionesEnEspera.any(_estaAnimando)) return;
      _soltarAnimaciones();
      _enFaseSegura(() {
        if (mounted) onBecomeVisible();
      });
    }

    for (final animacion in animaciones) {
      animacion.addStatusListener(oyente);
      _animacionesEnEspera.add(animacion);
    }
    _oyenteAnimaciones = oyente;
  }

  void Function(AnimationStatus)? _oyenteAnimaciones;

  void _soltarAnimaciones() {
    final oyente = _oyenteAnimaciones;
    if (oyente != null) {
      for (final animacion in _animacionesEnEspera) {
        animacion.removeStatusListener(oyente);
      }
    }
    _animacionesEnEspera.clear();
    _oyenteAnimaciones = null;
  }

  static bool _estaAnimando(Animation<double> animacion) =>
      animacion.status == AnimationStatus.forward ||
      animacion.status == AnimationStatus.reverse;

  /// El delegate —y los oyentes de animación— pueden avisar en plena
  /// construcción del Navigator; ahí `setState` e `invalidate` tirarían el
  /// framework.
  void _enFaseSegura(VoidCallback accion) {
    final fase = SchedulerBinding.instance.schedulerPhase;
    if (fase == SchedulerPhase.idle ||
        fase == SchedulerPhase.postFrameCallbacks) {
      accion();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) accion();
    });
  }
}
