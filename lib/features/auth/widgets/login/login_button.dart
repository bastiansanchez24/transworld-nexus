import 'package:flutter/material.dart';

import '../../../../core/widgets/nexus_components.dart';

/// Botón principal del flujo de autenticación (PrimaryGradientButton).
///
/// Estados: normal / presionado / loading / deshabilitado (`onPressed == null`).
class LoginButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Semantics(
      label: loading ? loadingSemanticsLabel : null,
      child: PrimaryGradientButton(
        label: label,
        loading: loading,
        onPressed: onPressed,
      ),
    );
  }
}
