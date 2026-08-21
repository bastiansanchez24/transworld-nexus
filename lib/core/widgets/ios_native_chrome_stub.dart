import 'package:flutter/widgets.dart';

import 'tw_components.dart';

/// En web no hay UIKit: las cabeceras siguen con [TwIconButton].
bool get usesNativeIosChrome => false;

/// Botón de cabecera. En web y tests de navegador es el chip Flutter.
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

  /// Homólogo SF Symbol; en web se ignora.
  final String? sfSymbol;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    return TwIconButton(
      icon: icon,
      iconSize: iconSize,
      size: size,
      variant: variant,
      onTap: onTap,
      tooltip: tooltip,
      danger: danger,
      loading: loading,
      badgeCount: badgeCount,
    );
  }
}
