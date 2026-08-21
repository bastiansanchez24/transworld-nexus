import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tw_tokens.dart';
import 'action_lock.dart';
import 'ios_glass_symbols.dart';
import 'tw_components.dart';

/// iPhone/iPad nativo: botones `UIButton` Liquid Glass en las cabeceras.
bool get usesNativeIosChrome => Platform.isIOS;

/// Botón de cabecera: `CNButton` glass en iOS 26+, chip Flutter en el resto.
///
/// Cuando aparece un modal sobre la ruta que contiene el botón, mantiene el
/// mismo `CNButton` montado y visible. Solo bloquea temporalmente sus toques
/// para que el `PlatformView` UIKit no atraviese el modal.
class TwIosGlassIconButton extends StatefulWidget {
  const TwIosGlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconSize = 20,
    this.size = 44,
    this.variant = TwIconButtonStyle.plain,
    this.tooltip,
    this.danger = false,
    this.loading = false,
    this.sfSymbol,
    this.badgeCount,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double iconSize;
  final double size;
  final TwIconButtonStyle variant;
  final String? tooltip;
  final bool danger;
  final bool loading;

  /// SF Symbol explícito; si falta se infiere de [icon].
  final String? sfSymbol;
  final int? badgeCount;

  @override
  State<TwIosGlassIconButton> createState() => _TwIosGlassIconButtonState();
}

class _TwIosGlassIconButtonState extends State<TwIosGlassIconButton> {
  late final int _profundidadModalAlMontar;

  @override
  void initState() {
    super.initState();
    _profundidadModalAlMontar = CNTabBarRouteObserver.anyModalDepth.value;
  }

  Widget _botonFlutter() {
    return TwIconButton(
      icon: widget.icon,
      iconSize: widget.iconSize,
      size: widget.size,
      variant: widget.variant,
      onTap: widget.onTap,
      tooltip: widget.tooltip,
      danger: widget.danger,
      loading: widget.loading,
      badgeCount: widget.badgeCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!usesNativeIosChrome || widget.loading) {
      return _botonFlutter();
    }

    final symbolName = widget.sfSymbol ?? sfSymbolForHeaderIcon(widget.icon);
    final isBrand = widget.variant == TwIconButtonStyle.brand;
    final Color tint;
    if (isBrand) {
      tint = AppColors.primary;
    } else if (widget.danger) {
      tint = TwColors.danger;
    } else {
      tint = AppColors.primary;
    }

    // `prominentGlass` pinta el fondo con el color de marca: ahí el símbolo tiene
    // que ir en blanco, igual que en [TwIconButton]. Sin esto el compartir del
    // menú de evento quedaba en gris oscuro sobre azul.
    final Color colorSimbolo;
    if (isBrand) {
      colorSimbolo = Colors.white;
    } else if (widget.danger) {
      colorSimbolo = TwColors.danger;
    } else {
      colorSimbolo = TwColors.inkSoft;
    }

    Widget boton = CNButton.icon(
      icon: symbolName == null
          ? null
          : CNSymbol(symbolName, size: 17, color: colorSimbolo),
      customIcon: symbolName == null ? widget.icon : null,
      tint: tint,
      enabled: widget.onTap != null,
      badgeCount: widget.badgeCount,
      onPressed: widget.onTap == null
          ? null
          : () => ActionLock.instance.run(widget.onTap!),
      // La coordinación de modales se hace sin sustituir ni desmontar este
      // PlatformView, para preservar Liquid Glass durante toda la transición.
      autoHideOnModal: false,
      config: CNButtonConfig(
        style: isBrand ? CNButtonStyle.prominentGlass : CNButtonStyle.glass,
        width: widget.size,
        minHeight: widget.size,
        customIconSize: 17,
      ),
    );

    if (widget.tooltip != null) {
      boton = Tooltip(message: widget.tooltip!, child: boton);
    }
    final nativo = Semantics(button: true, label: widget.tooltip, child: boton);

    return ValueListenableBuilder<int>(
      valueListenable: CNTabBarRouteObserver.anyModalDepth,
      child: nativo,
      builder: (context, profundidadActual, child) {
        final modalEncima = profundidadActual > _profundidadModalAlMontar;
        return IgnorePointer(ignoring: modalEncima, child: child);
      },
    );
  }
}
