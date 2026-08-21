import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:cupertino_native_better/utils/transition_observer.dart';
import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';
import 'sheet_depth_observer.dart';
import 'tw_bottom_nav_bar.dart';

export 'package:cupertino_native_better/cupertino_native_better.dart'
    show CNTabBarRouteObserver;

/// Observer que avisa al lado nativo cuándo hay una transición en curso, para
/// que las vistas Liquid Glass dejen de recalcularse durante el slide.
///
/// Solo iOS implementa `beginTransition` / `endTransition`: en Android, Windows
/// y macOS el canal levantaría `MissingPluginException` en cada navegación, así
/// que allí se devuelve un observer inerte.
NavigatorObserver crearCNTransitionObserver() =>
    Platform.isIOS ? CNTransitionObserver() : NavigatorObserver();

/// `UITabBar` nativo (Liquid Glass en iOS 26) pegado al borde inferior.
///
/// Sin `SafeArea`: el `UITabBar` ya reserva el home indicator por su cuenta y
/// añadirlo dos veces dejaba la barra flotando muy por encima del borde.
///
/// Dos comportamientos propios envuelven al `CNTabBar`:
///
/// * **Transición de página.** `autoHideOnPageTransition` deja el platform view
///   montado pero sin pintar mientras la ruta se desliza (evita que la capa
///   nativa tape el contenido Flutter, Issue #29 del paquete). Al terminar,
///   reaparece subiendo desde debajo del borde inferior. Nunca se dibuja una
///   segunda tab bar Flutter.
/// * **Hojas modales.** `autoHideOnModal` **destruye** el platform view y lo
///   recrea en t=0 de la animación de cierre, así que la píldora Liquid Glass
///   volvía a animarse mientras la hoja aún bajaba (el parpadeo del modal de
///   ajustes). Aquí se apaga y la barra se oculta con un [IndexedStack]: sigue
///   montada, solo deja de pintarse, y vuelve cuando [SheetDepthObserver] avisa
///   de que la hoja ya se fue del todo.
///
/// En tests y hosts que no son iOS ([Platform.isIOS] falso) pinta un
/// [CupertinoTabBar]: `CNTabBar` agenda un timer de platform views que
/// rompe `flutter test` y no hay UIKit que hospedar.
class IosNativeTabBar extends StatefulWidget {
  const IosNativeTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.tint,
  });

  final List<TwNavItemData> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color? tint;

  @override
  State<IosNativeTabBar> createState() => _IosNativeTabBarState();
}

class _IosNativeTabBarState extends State<IosNativeTabBar>
    with SingleTickerProviderStateMixin {
  Animation<double>? _animacionSecundaria;
  late final AnimationController _aparicion;
  late final Animation<Offset> _entradaDesdeAbajo;
  bool _hojaArriba = false;

  @override
  void initState() {
    super.initState();
    _aparicion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      value: 1,
    );
    _entradaDesdeAbajo = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _aparicion, curve: Curves.easeOutCubic));
    SheetDepthObserver.depth.addListener(_onProfundidadHojas);
    _hojaArriba = SheetDepthObserver.depth.value > 0;
  }

  /// La `secondaryAnimation` de la ruta del shell corre cuando se empuja o se
  /// saca una pantalla por encima: es la señal de "hay transición".
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nueva = ModalRoute.of(context)?.secondaryAnimation;
    if (identical(nueva, _animacionSecundaria)) return;
    _animacionSecundaria?.removeStatusListener(_onAnimacionSecundaria);
    _animacionSecundaria = nueva;
    _animacionSecundaria?.addStatusListener(_onAnimacionSecundaria);
    if (_animando(nueva)) _ocultarDuranteTransicion();
  }

  @override
  void dispose() {
    SheetDepthObserver.depth.removeListener(_onProfundidadHojas);
    _animacionSecundaria?.removeStatusListener(_onAnimacionSecundaria);
    _animacionSecundaria = null;
    _aparicion.dispose();
    super.dispose();
  }

  void _onProfundidadHojas() {
    final arriba = SheetDepthObserver.depth.value > 0;
    if (arriba == _hojaArriba || !mounted) return;
    setState(() => _hojaArriba = arriba);
    if (!arriba) _mostrarDesdeAbajo();
  }

  void _onAnimacionSecundaria(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.forward ||
        status == AnimationStatus.reverse) {
      _ocultarDuranteTransicion();
    } else if (!_hojaArriba) {
      _mostrarDesdeAbajo();
    }
  }

  void _ocultarDuranteTransicion() {
    _aparicion.stop();
    _aparicion.value = 0;
  }

  void _mostrarDesdeAbajo() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _aparicion.value = 1;
      return;
    }
    _aparicion.forward(from: 0);
  }

  static bool _animando(Animation<double>? animacion) =>
      animacion != null &&
      (animacion.status == AnimationStatus.forward ||
          animacion.status == AnimationStatus.reverse);

  @override
  Widget build(BuildContext context) {
    assert(widget.items.length >= 2, 'IosNativeTabBar requiere dos ítems');

    final accent = widget.tint ?? AppColors.primary;

    if (!Platform.isIOS) {
      return SafeArea(
        top: false,
        child: CupertinoTabBar(
          items: [
            for (final item in widget.items)
              BottomNavigationBarItem(icon: Icon(item.icon), label: item.label),
          ],
          currentIndex: widget.currentIndex,
          onTap: widget.onTap,
          activeColor: accent,
        ),
      );
    }

    final iconPt = GlassNavTokens.nativeIosIconSize;
    final Widget nativa = SlideTransition(
      position: _entradaDesdeAbajo,
      child: CNTabBar(
        items: [
          for (final item in widget.items)
            CNTabBarItem(
              label: item.label,
              icon: CNSymbol(item.sfSymbol, size: iconPt),
              activeIcon: CNSymbol(
                item.sfSymbolActive ?? item.sfSymbol,
                size: iconPt,
              ),
            ),
        ],
        currentIndex: widget.currentIndex,
        onTap: widget.onTap,
        tint: accent,
        iconSize: iconPt,
        // Ver la nota de clase: el ocultado por hoja modal lo hace el
        // [IndexedStack] de abajo, sin destruir el platform view.
        autoHideOnModal: false,
      ),
    );

    // Índice 1 = hueco vacío: la barra sigue montada (no se recrea) y
    // simplemente deja de pintarse mientras hay una hoja encima. El
    // `IndexedStack` mide todos sus hijos, así que el alto no cambia al
    // conmutar y el cuerpo no da un salto.
    return IndexedStack(
      index: _hojaArriba ? 1 : 0,
      sizing: StackFit.passthrough,
      children: [nativa, const SizedBox.shrink()],
    );
  }
}
