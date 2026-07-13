import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/require_admin.dart';
import '../../../data/models/evento_lead.dart';
import '../../../data/repositories/eventos_leads_repository.dart';
import '../providers/capturador_providers.dart';

class CrearEditarEventoLeadScreen extends StatelessWidget {
  const CrearEditarEventoLeadScreen({super.key, this.eventoId});

  final String? eventoId;

  @override
  Widget build(BuildContext context) {
    return RequireAdmin(
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
      if (mounted) context.pop();
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
    final eventoAsync = widget.eventoId == null
        ? null
        : ref.watch(eventoLeadByIdProvider(widget.eventoId!));

    if (eventoAsync != null) {
      eventoAsync.whenData(_precargar);
    }

    return AppScaffold(
      title: _esEdicion ? 'Editar evento' : 'Nuevo evento',
      actions: [
        if (_esEdicion)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _guardando ? null : _eliminar,
          ),
      ],
      body: eventoAsync != null && eventoAsync.isLoading && !_cargado
          ? const LoadingView()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del evento',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Fecha'),
                      subtitle: Text(DateFormat('dd/MM/yyyy').format(_fecha)),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: _elegirFecha,
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _paisController,
                      decoration: const InputDecoration(labelText: 'País'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _tematicaController,
                      decoration: const InputDecoration(labelText: 'Temática'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _guardando ? null : _guardar,
                      child: _guardando
                          ? const ButtonProgress()
                          : Text(
                              _esEdicion ? 'Guardar cambios' : 'Crear evento',
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
