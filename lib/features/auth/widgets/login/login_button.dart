import 'package:flutter/material.dart';

import '../../../../core/widgets/app_widgets.dart';
import 'login_theme.dart';

/// Botón principal del flujo de autenticación (56 px, radio 18).
///
/// Estados: normal / presionado (escala 0.97 + ripple propio de Material) /
/// loading (spinner y semántica anunciando el proceso) / deshabilitado
/// (`onPressed == null`).
class LoginButton extends StatefulWidget {
  const LoginButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingSemanticsLabel = 'Procesando…',
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String loadingSemanticsLabel;

  @override
  State<LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<LoginButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: LoginTheme.pressDuration,
      curve: LoginTheme.curve,
      child: Listener(
        onPointerDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: FilledButton(
          onPressed: enabled ? widget.onPressed : null,
          child: widget.loading
              ? Semantics(
                  label: widget.loadingSemanticsLabel,
                  child: const ButtonProgress(),
                )
              : Text(widget.label),
        ),
      ),
    );
  }
}
