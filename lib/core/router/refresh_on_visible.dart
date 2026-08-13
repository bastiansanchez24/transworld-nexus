import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  return router.routeInformationProvider.value.uri.path;
}

/// Vuelve a [listPath] tras guardar o borrar: `pop` si hay historial (la
/// lista quedó debajo) o `go` si se abrió el detalle sin esa pila.
void volverALista(BuildContext context, String listPath) {
  if (!context.mounted) return;
  final actual = currentLocationOf(context);
  if (actual == listPath) return;
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(listPath);
}

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
    _syncVisibility();
  }

  @override
  void dispose() {
    _locationProvider?.removeListener(_onLocation);
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
    if (visibleNow) onBecomeVisible();
  }
}
