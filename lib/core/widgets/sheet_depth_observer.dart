import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Cuenta cuántas hojas modales hay presentadas sobre la app.
///
/// Existe porque el contador equivalente de `cupertino_native_better`
/// (`CNTabBarRouteObserver.modalDepth`) baja de forma **síncrona** en t=0 de la
/// animación de salida: el `UITabBar` se recreaba mientras la hoja todavía
/// estaba bajando y la píldora Liquid Glass volvía a animarse desde cero —el
/// parpadeo al cerrar el modal de ajustes.
///
/// Aquí la bajada se difiere hasta que la animación de la ruta reporta
/// `dismissed`, de modo que la tab bar solo vuelve a pintarse cuando la hoja ya
/// no está en pantalla. [IosNativeTabBar] escucha [depth] y oculta la barra sin
/// destruirla, así que tampoco hay recreación que animar.
class SheetDepthObserver extends NavigatorObserver {
  SheetDepthObserver();

  static final ValueNotifier<int> _depth = ValueNotifier<int>(0);

  /// Hojas modales presentadas ahora mismo.
  static ValueListenable<int> get depth => _depth;

  /// Rutas que tapan la tab bar entera: `ModalBottomSheetRoute` (todas las
  /// `showModalBottomSheet` de la app) y `CupertinoSheetRoute`.
  ///
  /// Los popups pequeños —diálogos, action sheets— quedan fuera a propósito:
  /// no llegan a cubrir la barra y esconderla se vería como un salto.
  static bool esHoja(Route<dynamic> route) {
    return route.runtimeType.toString().contains('Sheet');
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (esHoja(route)) _depth.value++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!esHoja(route)) return;
    _bajarCuandoTermine(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Retirada sin animación: diferir aquí no dispararía nunca.
    if (esHoja(route)) _bajar();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null && esHoja(oldRoute)) _bajar();
    if (newRoute != null && esHoja(newRoute)) _depth.value++;
  }

  void _bajar() {
    final siguiente = _depth.value - 1;
    _depth.value = siguiente < 0 ? 0 : siguiente;
  }

  /// Espera a que los píxeles de la hoja hayan desaparecido de verdad.
  void _bajarCuandoTermine(Route<dynamic> route) {
    final anim = route is TransitionRoute ? route.animation : null;
    if (anim == null || anim.status == AnimationStatus.dismissed) {
      _bajar();
      return;
    }
    late void Function(AnimationStatus) listener;
    listener = (status) {
      if (status != AnimationStatus.dismissed) return;
      anim.removeStatusListener(listener);
      _bajar();
    };
    anim.addStatusListener(listener);
  }

  /// Solo para tests: deja el contador en cero entre casos.
  @visibleForTesting
  static void reiniciarParaTest() => _depth.value = 0;
}
