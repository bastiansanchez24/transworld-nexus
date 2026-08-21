import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:cupertino_native_better/utils/transition_observer.dart';
import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';
import '../theme/tw_tokens.dart';
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
/// Dos comportamientos propios envuelven al `CNTabBar`, porque los del paquete
/// se ven mal en esta app:
///
/// * **Transición de página.** `autoHideOnPageTransition` deja el platform view
///   montado pero sin pintar mientras la ruta se desliza (evita que la capa
///   nativa tape el contenido Flutter, Issue #29 del paquete). El efecto
///   colateral era que la barra reaparecía de golpe *al terminar* el pop. Aquí
///   se pinta una réplica Flutter durante la transición, de modo que la barra
///   acompaña el slide.
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

class _IosNativeTabBarState extends State<IosNativeTabBar> {
  Animation<double>? _animacionSecundaria;
  bool _enTransicion = false;
  bool _hojaArriba = false;

  @override
  void initState() {
    super.initState();
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
    // Asignación directa, no `setState`: esto corre dentro del build.
    _enTransicion = _animando(nueva);
  }

  @override
  void dispose() {
    SheetDepthObserver.depth.removeListener(_onProfundidadHojas);
    _animacionSecundaria?.removeStatusListener(_onAnimacionSecundaria);
    _animacionSecundaria = null;
    super.dispose();
  }

  void _onProfundidadHojas() {
    final arriba = SheetDepthObserver.depth.value > 0;
    if (arriba == _hojaArriba || !mounted) return;
    setState(() => _hojaArriba = arriba);
  }

  void _onAnimacionSecundaria(AnimationStatus _) {
    final animando = _animando(_animacionSecundaria);
    if (animando == _enTransicion || !mounted) return;
    setState(() => _enTransicion = animando);
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
    final Widget nativa = CNTabBar(
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
    );

    // Índice 1 = hueco vacío: la barra sigue montada (no se recrea) y
    // simplemente deja de pintarse mientras hay una hoja encima. El
    // `IndexedStack` mide todos sus hijos, así que el alto no cambia al
    // conmutar y el cuerpo no da un salto.
    final Widget barra = IndexedStack(
      index: _hojaArriba ? 1 : 0,
      sizing: StackFit.passthrough,
      children: [nativa, const SizedBox.shrink()],
    );

    // Con una hoja encima la barra debe seguir escondida aunque haya
    // transición: pintar la réplica ahí la haría reaparecer sobre la hoja.
    if (!_enTransicion || _hojaArriba) return barra;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        barra,
        Positioned.fill(
          child: IgnorePointer(
            child: _ReplicaTabBar(
              items: widget.items,
              currentIndex: widget.currentIndex,
              tint: accent,
            ),
          ),
        ),
      ],
    );
  }
}

/// Copia Flutter de la tab bar nativa para los ~300 ms de una transición.
///
/// Sin blur a propósito: durante el slide hay dos páginas componiendo a la vez
/// y un `BackdropFilter` extra es justo lo que se está quitando del resto de
/// las cabeceras. Un velo casi opaco es indistinguible en movimiento.
class _ReplicaTabBar extends StatelessWidget {
  const _ReplicaTabBar({
    required this.items,
    required this.currentIndex,
    required this.tint,
  });

  final List<TwNavItemData> items;
  final int currentIndex;
  final Color tint;

  /// Igual que el símbolo nativo: el `IconData` de Material necesita algo más
  /// de caja para leerse a la misma escala visual.
  static const _iconSize = 22.0;
  static const _labelSize = 10.0;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.94),
          border: const Border(
            top: BorderSide(color: TwColors.border07, width: 0.5),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: safeBottom),
          child: SizedBox(
            height: GlassNavTokens.nativeIosHeight,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _ReplicaItem(
                      item: items[i],
                      selected: i == currentIndex,
                      tint: tint,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplicaItem extends StatelessWidget {
  const _ReplicaItem({
    required this.item,
    required this.selected,
    required this.tint,
  });

  final TwNavItemData item;
  final bool selected;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final color = selected ? tint : CupertinoColors.inactiveGray;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(item.icon, size: _ReplicaTabBar._iconSize, color: color),
        const SizedBox(height: 2),
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: _ReplicaTabBar._labelSize,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
