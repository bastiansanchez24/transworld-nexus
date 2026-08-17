import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../core/widgets/require_admin.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../usuarios/providers/usuarios_providers.dart';
import '../providers/acceso_evento_providers.dart';
import '../providers/eventos_providers.dart';
import '../widgets/selector_usuarios_acceso.dart';

/// Asigna qué usuarios y usuarios externos pueden operar un evento.
class GestionarAccesoEventoScreen extends StatelessWidget {
  const GestionarAccesoEventoScreen({super.key, required this.eventoId});

  final String eventoId;

  @override
  Widget build(BuildContext context) {
    return RequireAdmin(
      builder: (context) => _GestionarAccesoEventoBody(eventoId: eventoId),
    );
  }
}

class _GestionarAccesoEventoBody extends ConsumerStatefulWidget {
  const _GestionarAccesoEventoBody({required this.eventoId});

  final String eventoId;

  @override
  ConsumerState<_GestionarAccesoEventoBody> createState() =>
      _GestionarAccesoEventoBodyState();
}

class _GestionarAccesoEventoBodyState
    extends ConsumerState<_GestionarAccesoEventoBody> {
  final Set<String> _usuarioIds = {};
  bool _seleccionInicializada = false;
  bool _guardando = false;

  void _precargarSiCorresponde(Set<String>? ids) {
    if (_seleccionInicializada || ids == null) return;
    _usuarioIds
      ..clear()
      ..addAll(ids);
    _seleccionInicializada = true;
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .configurarAccesoEvento(
            eventoId: widget.eventoId,
            usuarioIds: _usuarioIds.toList(),
          );
      ref.invalidate(usuariosAutorizadosEventoProvider(widget.eventoId));
      ref.invalidate(usuariosListProvider);
      if (!mounted) return;
      showAppSnackBar(context, 'Acceso al evento actualizado.');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventoAsync = ref.watch(eventoByIdProvider(widget.eventoId));
    final usuariosAsync = ref.watch(usuariosAsignablesAccesoProvider);
    final autorizadosAsync = ref.watch(
      usuariosAutorizadosEventoProvider(widget.eventoId),
    );

    _precargarSiCorresponde(autorizadosAsync.valueOrNull);

    final cargando =
        (eventoAsync.isLoading && !eventoAsync.hasValue) ||
        (usuariosAsync.isLoading && !usuariosAsync.hasValue) ||
        (autorizadosAsync.isLoading && !autorizadosAsync.hasValue);

    return AppScaffold(
      title: 'Acceso al evento',
      body: cargando
          ? const LoadingView()
          : eventoAsync.hasError ||
                usuariosAsync.hasError ||
                autorizadosAsync.hasError
          ? ErrorView(
              message: 'No se pudo cargar el acceso del evento.',
              onRetry: () {
                ref.invalidate(eventoByIdProvider(widget.eventoId));
                ref.invalidate(usuariosAsignablesAccesoProvider);
                ref.invalidate(
                  usuariosAutorizadosEventoProvider(widget.eventoId),
                );
                setState(() => _seleccionInicializada = false);
              },
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    eventoAsync.valueOrNull?.nombre ?? 'Evento',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Administradores y organizadores ya tienen acceso a todos los eventos. Aquí se autoriza a usuarios y usuarios externos.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SelectorUsuariosAcceso(
                    usuarios: usuariosAsync.valueOrNull ?? const [],
                    seleccionados: _usuarioIds,
                    enabled: !_guardando,
                    permiteNuevosExternos:
                        eventoAsync.valueOrNull != null &&
                        eventoAsync.valueOrNull!.activo &&
                        !eventoAsync.valueOrNull!.yaOcurrio,
                    onChanged: (ids) => setState(() {
                      _usuarioIds
                        ..clear()
                        ..addAll(ids);
                    }),
                  ),
                  const SizedBox(height: 28),
                  PrimaryGradientButton(
                    label: _guardando ? 'Guardando…' : 'Guardar acceso',
                    loading: _guardando,
                    onPressed: _guardando ? null : _guardar,
                  ),
                ],
              ),
            ),
    );
  }
}
