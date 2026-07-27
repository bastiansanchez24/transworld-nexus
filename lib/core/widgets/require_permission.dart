import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/perfil.dart';
import '../../features/auth/providers/auth_providers.dart';
import 'app_scaffold.dart';
import 'app_widgets.dart';

/// Envoltorio para pantallas restringidas por permiso de negocio.
///
/// Capa de UX; la seguridad real la aplican RLS y RPCs en Supabase.
class RequirePermission extends ConsumerWidget {
  const RequirePermission({
    super.key,
    required this.allowed,
    required this.builder,
    this.deniedTitle = 'Acceso restringido',
    this.deniedMessage = 'No tienes permiso para acceder a esta sección.',
  });

  final bool Function(Perfil perfil) allowed;
  final WidgetBuilder builder;
  final String deniedTitle;
  final String deniedMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfilAsync = ref.watch(currentPerfilProvider);

    return perfilAsync.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => const Scaffold(
        body: ErrorView(message: 'No se pudo verificar tu perfil.'),
      ),
      data: (perfil) {
        if (perfil == null || !perfil.activo || !allowed(perfil)) {
          return AppScaffold(
            title: deniedTitle,
            body: EmptyStateView(
              icon: Icons.lock_outline,
              message: deniedMessage,
            ),
          );
        }
        return builder(context);
      },
    );
  }
}

/// Atajo para pantallas solo de administrador (gestión de usuarios).
class RequireAdmin extends StatelessWidget {
  const RequireAdmin({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return RequirePermission(
      allowed: (p) => p.canManageUsers,
      deniedMessage: 'Esta sección es solo para administradores.',
      builder: builder,
    );
  }
}
