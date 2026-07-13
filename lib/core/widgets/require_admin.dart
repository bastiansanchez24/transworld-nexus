import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';
import 'app_scaffold.dart';
import 'app_widgets.dart';

/// Envoltorio para pantallas que solo debe poder abrir un administrador.
///
/// Esto es una capa de UX (ocultar/backear la pantalla), **no** la medida
/// de seguridad real: la seguridad real la aplican las políticas RLS y el
/// trigger de `supabase/schema.sql` (ver Sección 8.2/17.6 de la auditoría).
/// Aun si alguien saltara este widget, el backend rechazaría la operación.
class RequireAdmin extends ConsumerWidget {
  const RequireAdmin({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfilAsync = ref.watch(currentPerfilProvider);

    return perfilAsync.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        body: ErrorView(message: 'No se pudo verificar tu perfil.'),
      ),
      data: (perfil) {
        if (perfil == null || !perfil.isAdmin) {
          return const AppScaffold(
            title: 'Acceso restringido',
            body: EmptyStateView(
              icon: Icons.lock_outline,
              message: 'Esta sección es solo para administradores.',
            ),
          );
        }
        return builder(context);
      },
    );
  }
}
