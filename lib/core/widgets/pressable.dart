import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Escala animada en press (HANDOFF §5 / Pressable).
class Pressable extends StatefulWidget {
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
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduce = AppMotion.reduceMotion(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled && widget.onTap != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.enabled && widget.onTap != null
          ? (_) => setState(() => _pressed = false)
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.enabled ? widget.onTap : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      child: AnimatedScale(
        scale: _pressed && !reduce ? widget.scale : 1,
        duration: reduce ? Duration.zero : AppMotion.press,
        curve: AppMotion.ease,
        child: widget.child,
      ),
    );
  }
}
