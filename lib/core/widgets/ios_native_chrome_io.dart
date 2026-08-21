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
class TwIosGlassIconButton extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    if (!usesNativeIosChrome || loading) {
      return TwIconButton(
        icon: icon,
        iconSize: iconSize,
        size: size,
        variant: variant,
        onTap: onTap,
        tooltip: tooltip,
        danger: danger,
        loading: loading,
      );
    }

    final symbolName = sfSymbol ?? sfSymbolForHeaderIcon(icon);
    final isBrand = variant == TwIconButtonStyle.brand;
    final Color tint;
    if (isBrand) {
      tint = AppColors.primary;
    } else if (danger) {
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
    } else if (danger) {
      colorSimbolo = TwColors.danger;
    } else {
      colorSimbolo = TwColors.inkSoft;
    }

    Widget boton = CNButton.icon(
      icon: symbolName == null
          ? null
          : CNSymbol(symbolName, size: 17, color: colorSimbolo),
      customIcon: symbolName == null ? icon : null,
      tint: tint,
      enabled: onTap != null,
      onPressed: onTap == null ? null : () => ActionLock.instance.run(onTap!),
      config: CNButtonConfig(
        style: isBrand ? CNButtonStyle.prominentGlass : CNButtonStyle.glass,
        width: size,
        minHeight: size,
        customIconSize: 17,
      ),
    );

    if (tooltip != null) {
      boton = Tooltip(message: tooltip!, child: boton);
    }
    return Semantics(button: true, label: tooltip, child: boton);
  }
}
