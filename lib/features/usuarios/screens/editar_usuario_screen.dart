import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_role.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/require_admin.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/usuarios_providers.dart';

/// Cambia rol / estado de un usuario a través del RPC
/// `rpe_actualizar_rol_usuario`, nunca con un `UPDATE` directo sobre
/// `perfiles.rol` (ver AuthRepository.actualizarRolUsuario y la Sección
/// 8.2/17.6 de la auditoría sobre escalación de privilegios).
class EditarUsuarioScreen extends StatelessWidget {
  const EditarUsuarioScreen({super.key, required this.usuarioId});

  final String usuarioId;

  @override
  Widget build(BuildContext context) {
    return RequireAdmin(
      builder: (context) => _EditarUsuarioBody(usuarioId: usuarioId),
    );
  }
}

class _EditarUsuarioBody extends ConsumerStatefulWidget {
  const _EditarUsuarioBody({required this.usuarioId});

  final String usuarioId;

  @override
  ConsumerState<_EditarUsuarioBody> createState() => _EditarUsuarioBodyState();
}

class _EditarUsuarioBodyState extends ConsumerState<_EditarUsuarioBody> {
  AppRole? _rolSeleccionado;
  bool _activo = true;
  bool _cargado = false;
  bool _guardando = false;
  bool _eliminando = false;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      if (_rolSeleccionado != null) {
        await repo.actualizarRolUsuario(widget.usuarioId, _rolSeleccionado!.value);
      }
      await repo.establecerActivo(widget.usuarioId, _activo);

      ref.invalidate(usuariosListProvider);
      ref.invalidate(usuarioPorIdProvider(widget.usuarioId));

      if (mounted) {
        showAppSnackBar(context, 'Usuario actualizado.');
        context.pop();
      }
    } on PostgrestException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'No se pudo actualizar.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar(String nombre) async {
    final confirmado = await confirmDialog(
      context,
      title: 'Eliminar usuario',
      message: 'Se eliminará la cuenta de "$nombre" y su acceso a la app. '
          'Sus acreditaciones quedarán como "Usuario eliminado". '
          'Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmado || !mounted) return;

    setState(() => _eliminando = true);
    try {
      final eliminado = await ref
          .read(authRepositoryProvider)
          .eliminarUsuario(widget.usuarioId);
      ref.invalidate(usuariosListProvider);
      if (mounted) {
        showAppSnackBar(
          context,
          eliminado
              ? 'Usuario eliminado.'
              : 'La cuenta quedó desactivada: otra aplicación de la base '
                  'compartida aún referencia sus datos, pero perdió el acceso.',
        );
        context.pop();
      }
    } on PostgrestException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'No se pudo eliminar el usuario.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _eliminando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuarioAsync = ref.watch(usuarioPorIdProvider(widget.usuarioId));

    return AppScaffold(
      title: 'Editar usuario',
      body: usuarioAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => const ErrorView(message: 'No se pudo cargar el usuario.'),
        data: (usuario) {
          if (!_cargado) {
            _rolSeleccionado = usuario.rol;
            _activo = usuario.activo;
            _cargado = true;
          }
          final esCuentaPropia =
              ref.watch(currentPerfilProvider).valueOrNull?.id ==
                  widget.usuarioId;
          final ocupado = _guardando || _eliminando;

          return SingleChildScrollView(
            padding: AppSpacing.screen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        usuario.nombreCompleto.isNotEmpty
                            ? usuario.nombreCompleto[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Text(
                        usuario.nombreCompleto,
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                    child: Column(
                      children: [
                        DropdownButtonFormField<AppRole>(
                          initialValue: _rolSeleccionado,
                          decoration: const InputDecoration(labelText: 'Rol'),
                          items: AppRole.values
                              .map((r) => DropdownMenuItem(
                                  value: r, child: Text(r.label)))
                              .toList(),
                          onChanged: ocupado
                              ? null
                              : (v) => setState(() => _rolSeleccionado = v),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Cuenta activa'),
                          value: _activo,
                          onChanged: ocupado
                              ? null
                              : (v) => setState(() => _activo = v),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                FilledButton(
                  onPressed: ocupado ? null : _guardar,
                  child: _guardando
                      ? const ButtonProgress()
                      : const Text('Guardar cambios'),
                ),
                if (!esCuentaPropia) ...[
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.5)),
                    ),
                    onPressed: ocupado
                        ? null
                        : () => _eliminar(usuario.nombreCompleto),
                    icon: _eliminando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.error),
                          )
                        : const Icon(Icons.delete_outline_rounded),
                    label: const Text('Eliminar usuario'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
