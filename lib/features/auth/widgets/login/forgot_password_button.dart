import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';

class ForgotPasswordButton extends StatelessWidget {
  const ForgotPasswordButton({super.key, this.enabled = true});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      // Área táctil mínima de 44x44 (accesibilidad).
      style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
      onPressed:
          enabled ? () => context.push(RoutePaths.recuperarPassword) : null,
      child: const Text('Olvidé mi contraseña'),
    );
  }
}
