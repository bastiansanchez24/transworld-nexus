import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../core/widgets/require_permission.dart';
import '../../../data/models/evento_lead.dart';
import '../../../data/repositories/eventos_leads_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/capturador_providers.dart';

class CrearEditarEventoLeadScreen extends StatelessWidget {
  const CrearEditarEventoLeadScreen({super.key, this.eventoId});

  final String? eventoId;

  @override
  Widget build(BuildContext context) {
    return RequirePermission(
      allowed: (p) => p.canCreateContent,
      deniedMessage:
          'Solo administradores y organizadores pueden crear o editar campañas.',
      builder: (context) => _CrearEditarEventoLeadForm(eventoId: eventoId),
    );
  }
}

class _CrearEditarEventoLeadForm extends ConsumerStatefulWidget {
  const _CrearEditarEventoLeadForm({this.eventoId});

  final String? eventoId;

  @override
  ConsumerState<_CrearEditarEventoLeadForm> createState() =>
      _CrearEditarEventoLeadFormState();
}

class _CrearEditarEventoLeadFormState
    extends ConsumerState<_CrearEditarEventoLeadForm> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _paisController = TextEditingController();
  final _tematicaController = TextEditingController();

  DateTime _fecha = DateTime.now();
  bool _guardando = false;
  bool _cargado = false;

  bool get _esEdicion => widget.eventoId != null;

  @override
  void dispose() {
    _nombreController.dispose();
    _paisController.dispose();
    _tematicaController.dispose();
    super.dispose();
  }

  void _precargar(EventoLead evento) {
    if (_cargado) return;
    _cargado = true;
    _nombreController.text = evento.nombre;
    _paisController.text = evento.pais ?? '';
    _tematicaController.text = evento.tematica ?? '';
    _fecha = evento.fecha;
  }

  Future<void> _elegirFecha() async {
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (seleccionada != null) setState(() => _fecha = seleccionada);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      final evento = EventoLead(
        id: widget.eventoId ?? '',
        nombre: _nombreController.text.trim(),
        fecha: _fecha,
        pais: _paisController.text.trim().isEmpty
            ? null
            : _paisController.text.trim(),
        tematica: _tematicaController.text.trim().isEmpty
            ? null
            : _tematicaController.text.trim(),
      );

      final repo = ref.read(eventosLeadsRepositoryProvider);
      if (_esEdicion) {
        await repo.actualizar(widget.eventoId!, evento.toInsertMap());
      } else {
        await repo.crear(evento);
      }

      ref.invalidate(eventosLeadsListProvider);
      if (widget.eventoId != null) {
        ref.invalidate(eventoLeadByIdProvider(widget.eventoId!));
      }

      if (mounted) {
        showAppSnackBar(
          context,
          _esEdicion ? 'Evento actualizado.' : 'Evento creado.',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          'No se pudo guardar el evento.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar() async {
    final confirmado = await confirmDialog(
      context,
      title: 'Eliminar evento',
      message:
          'Esta acción no se puede deshacer. ¿Eliminar el evento de captura?',
      confirmLabel: 'Eliminar',
    );
    if (!confirmado) return;

    try {
      await ref
          .read(eventosLeadsRepositoryProvider)
          .eliminar(widget.eventoId!);
      ref.invalidate(eventosLeadsListProvider);
      ref.invalidate(eventoLeadByIdProvider(widget.eventoId!));
      if (mounted) context.go(RoutePaths.capturador);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          'No se pudo eliminar el evento.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = ref.watch(isAdminProvider);
    final eventoAsync = widget.eventoId == null
        ? null
        : ref.watch(eventoLeadByIdProvider(widget.eventoId!));

    if (eventoAsync != null) {
      eventoAsync.whenData(_precargar);
    }

    return AppScaffold(
      title: _esEdicion ? 'Editar campaña' : 'Nueva campaña',
      actions: [
        if (_esEdicion && esAdmin)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _guardando ? null : _eliminar,
          ),
      ],
      body: eventoAsync != null && eventoAsync.isLoading && !_cargado
          ? const LoadingView()
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _FieldLabel('Nombre de la campaña'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nombreController,
                      decoration: const InputDecoration(
                        hintText: 'Ej. Campaña retail 2026',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 14),
                    const _FieldLabel('Fecha'),
                    const SizedBox(height: 6),
                    Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      child: InkWell(
                        onTap: _elegirFecha,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 13),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(AppRadius.input),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  DateFormat('dd/MM/yyyy').format(_fecha),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _FieldLabel('País'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _paisController,
                      decoration: const InputDecoration(hintText: 'Chile'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 14),
                    const _FieldLabel('Temática'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _tematicaController,
                      decoration: const InputDecoration(
                        hintText: 'Ej. Telecomunicaciones',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 24),
                    PrimaryGradientButton(
                      label: _esEdicion ? 'Guardar cambios' : 'Crear campaña',
                      loading: _guardando,
                      onPressed: _guardando ? null : _guardar,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    );
  }
}
