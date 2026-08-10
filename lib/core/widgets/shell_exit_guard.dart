import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_widgets.dart';

/// Confirma antes de cerrar la app al pulsar atrás en un tab raíz del shell
/// (Inicio, Eventos, Leads, Usuarios). Debe envolver la pantalla dentro de
/// cada rama del [StatefulShellRoute], no el scaffold exterior: así el
/// [PopScope] queda en la ruta activa del navigator anidado y recibe el back
/// desde el primer frame (el PopScope en el padre del shell no lo intercepta).
class ShellExitGuard extends StatelessWidget {
  const ShellExitGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final salir = await confirmDialog(
          context,
          title: 'Salir de la aplicación',
          message: '¿Deseas cerrar RegisPro?',
          confirmLabel: 'Salir',
        );
        if (salir && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: child,
    );
  }
}
