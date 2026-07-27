import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../data/models/registrado.dart';
import '../../../data/offline/sync_queue_service.dart';
import '../../../data/repositories/registrados_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/registrados_providers.dart';

class EditarRegistradoScreen extends ConsumerStatefulWidget {
  const EditarRegistradoScreen({
    super.key,
    required this.eventoId,
    required this.registradoId,
  });

  final String eventoId;
  final String registradoId;

  @override
  ConsumerState<EditarRegistradoScreen> createState() => _EditarRegistradoScreenState();
}

class _EditarRegistradoScreenState extends ConsumerState<EditarRegistradoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _empresaController = TextEditingController();
  final _cargoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _rutController = TextEditingController();
  final _patenteController = TextEditingController();
  bool _acreditado = false;
  bool _cargado = false;
  bool _guardando = false;

  void _precargar(Registrado r) {
    if (_cargado) return;
    _cargado = true;
    _nombreController.text = r.nombreCompleto;
    _empresaController.text = r.empresa ?? '';
    _cargoController.text = r.cargo ?? '';
    _telefonoController.text = r.telefono ?? '';
    _rutController.text = r.rut ?? '';
    _patenteController.text = r.patente ?? '';
    _acreditado = r.acreditado;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final cambios = {
      'nombre_completo': _nombreController.text.trim(),
      'empresa': _empresaController.text.trim(),
      'cargo': _cargoController.text.trim(),
      'telefono': _telefonoController.text.trim(),
      'rut': _rutController.text.trim(),
      'patente': _patenteController.text.trim(),
      'acreditado': _acreditado,
    };

    try {
      final isOnline = ref.read(isOnlineProvider);
      final esPendiente = widget.registradoId.startsWith('local_');

      if (isOnline && !esPendiente) {
        await ref.read(registradosRepositoryProvider).actualizar(widget.registradoId, cambios);
      } else {
        await ref.read(syncQueueServiceProvider.notifier).enqueueUpdate(
              table: 'registrados',
              entityId: widget.registradoId,
              changes: cambios,
            );
      }
      ref.invalidate(registradosPorEventoProvider(widget.eventoId));
      if (mounted) {
        showAppSnackBar(context, 'Cambios guardados.');
        context.pop();
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'No se pudo guardar.', isError: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar() async {
    final confirmado = await confirmDialog(
      context,
      title: 'Eliminar registrado',
      message: '¿Eliminar este registro? Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmado) return;
    try {
      await ref.read(registradosRepositoryProvider).eliminar(widget.registradoId);
      ref.invalidate(registradosPorEventoProvider(widget.eventoId));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'No se pudo eliminar.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = ref.watch(isAdminProvider);
    final registradosAsync = ref.watch(registradosPorEventoProvider(widget.eventoId));

    return AppScaffold(
      title: 'Editar registrado',
      actions: [
        if (esAdmin)
          IconButton(
            icon: const Icon(Symbols.delete_outline_rounded),
            onPressed: _eliminar,
          ),
      ],
      body: registradosAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => const ErrorView(message: 'No se pudo cargar.'),
              data: (registrados) {
                final registrado = registrados.where((r) => r.id == widget.registradoId).firstOrNull;
                if (registrado == null) {
                  return const EmptyStateView(
                    icon: Symbols.person_off_rounded,
                    message: 'No se encontró este registro.',
                  );
                }
                _precargar(registrado);

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.xl,
                    AppSpacing.screenH,
                    AppSpacing.xxxl,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          registrado.email,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextFormField(
                          controller: _nombreController,
                          decoration: const InputDecoration(labelText: 'Nombre completo'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                        ),
                        AppSpacing.field,
                        TextFormField(
                          controller: _empresaController,
                          decoration: const InputDecoration(labelText: 'Empresa'),
                        ),
                        AppSpacing.field,
                        TextFormField(
                          controller: _cargoController,
                          decoration: const InputDecoration(labelText: 'Cargo'),
                        ),
                        AppSpacing.field,
                        TextFormField(
                          controller: _telefonoController,
                          decoration: const InputDecoration(labelText: 'Teléfono'),
                        ),
                        AppSpacing.field,
                        TextFormField(
                          controller: _rutController,
                          decoration: const InputDecoration(labelText: 'RUT / RUC'),
                        ),
                        AppSpacing.field,
                        TextFormField(
                          controller: _patenteController,
                          decoration: const InputDecoration(labelText: 'Patente'),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _ToggleRow(
                          title: 'Acreditado',
                          subtitle: 'Estado de ingreso al evento',
                          value: _acreditado,
                          onChanged: (v) => setState(() => _acreditado = v),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        PrimaryGradientButton(
                          label: 'Guardar cambios',
                          loading: _guardando,
                          onPressed: _guardando ? null : _guardar,
                        ),
                      ],
                    ),
                  ),
                );
              },
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          NexusToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
