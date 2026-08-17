import 'package:flutter/material.dart';

import 'tw_components.dart';

/// Escala animada en press.
///
/// Es [TwPressable] con el nombre que ya usan las pantallas: un solo feedback
/// táctil en toda la app (0.98 en 90 ms, sin ripple de Material).
class Pressable extends StatelessWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.975,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TwPressable(
      scale: scale,
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      child: child,
    );
  }
}
