import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/require_admin.dart';
import '../../../data/models/perfil.dart';
import '../providers/usuarios_providers.dart';

class GestionarUsuariosScreen extends StatelessWidget {
  const GestionarUsuariosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RequireAdmin(builder: (context) => const _GestionarUsuariosBody());
  }
}

class _GestionarUsuariosBody extends ConsumerStatefulWidget {
  const _GestionarUsuariosBody();

  @override
  ConsumerState<_GestionarUsuariosBody> createState() =>
      _GestionarUsuariosBodyState();
}

class _GestionarUsuariosBodyState
    extends ConsumerState<_GestionarUsuariosBody> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final usuariosAsync = ref.watch(usuariosListProvider);

    return AppScaffold(
      title: 'Gestionar usuarios',
      headerBottom: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Buscar por nombre o rol...',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            prefixIcon:
                const Icon(Icons.search, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surfaceMuted,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
          onChanged: (v) =>
              setState(() => _busqueda = v.trim().toLowerCase()),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(usuariosListProvider),
        child: usuariosAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: 'No se pudieron cargar los usuarios.',
            onRetry: () => ref.invalidate(usuariosListProvider),
          ),
          data: (usuarios) {
            final filtrados = usuarios.where((u) {
              if (u.id == SupabaseTables.perfilUsuarioEliminadoId) {
                return false;
              }
              if (_busqueda.isEmpty) return true;
              return u.nombreCompleto.toLowerCase().contains(_busqueda) ||
                  u.rol.label.toLowerCase().contains(_busqueda);
            }).toList();

            if (filtrados.isEmpty) {
              return EmptyStateView(
                icon: _busqueda.isEmpty
                    ? Icons.people_outline_rounded
                    : Icons.search_off_rounded,
                message: _busqueda.isEmpty
                    ? 'No hay usuarios todavía.'
                    : 'No hay usuarios que coincidan con "$_busqueda".',
              );
            }

            // Lista agrupada estilo iOS: una sola tarjeta contenedora con
            // separadores alineados al texto.
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.screen,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                      left: AppSpacing.xs, bottom: AppSpacing.sm),
                  child: Text(
                    '${filtrados.length} ${filtrados.length == 1 ? 'USUARIO' : 'USUARIOS'}',
                    style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < filtrados.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 72),
                        _UsuarioTile(usuario: filtrados[i]),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UsuarioTile extends StatelessWidget {
  const _UsuarioTile({required this.usuario});

  final Perfil usuario;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: usuario.activo
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.surfaceMuted,
        child: Text(
          usuario.nombreCompleto.isNotEmpty
              ? usuario.nombreCompleto[0].toUpperCase()
              : '?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color:
                usuario.activo ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
      title: Text(
        usuario.nombreCompleto,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        usuario.rol.label,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!usuario.activo)
            Container(
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Text(
                'Inactivo',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textSecondary),
        ],
      ),
      onTap: () => context.push(RoutePaths.editarUsuario(usuario.id)),
    );
  }
}
