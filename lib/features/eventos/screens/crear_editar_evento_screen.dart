import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/require_admin.dart';
import '../../../data/models/evento.dart';
import '../../../data/repositories/eventos_repository.dart';
import '../../../data/repositories/storage_repository.dart';
import '../providers/eventos_providers.dart';

/// Crear o editar un evento. Restringido a administradores: la política
/// `rpe_eventos_insert` / `_update` de `supabase/schema.sql` ya lo exige a
/// nivel de base de datos (ver Sección 8.2/17.6 de la auditoría); acá se
/// refuerza con [RequireAdmin] para dar feedback inmediato en la UI.
class CrearEditarEventoScreen extends StatelessWidget {
  const CrearEditarEventoScreen({super.key, this.eventoId});

  final String? eventoId;

  @override
  Widget build(BuildContext context) {
    return RequireAdmin(
      builder: (context) => _CrearEditarEventoForm(eventoId: eventoId),
    );
  }
}

class _CrearEditarEventoForm extends ConsumerStatefulWidget {
  const _CrearEditarEventoForm({this.eventoId});

  final String? eventoId;

  @override
  ConsumerState<_CrearEditarEventoForm> createState() =>
      _CrearEditarEventoFormState();
}

class _CrearEditarEventoFormState extends ConsumerState<_CrearEditarEventoForm> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _paisController = TextEditingController();
  final _tematicaController = TextEditingController();
  final _direccionController = TextEditingController();
  final _lugarController = TextEditingController();

  DateTime _fecha = DateTime.now();
  bool _certificacion = false;
  bool _activo = true;
  TipoRegistroEvento _tipoRegistro = TipoRegistroEvento.comercial;
  Uint8List? _imagenBytes;
  String? _imagenUrlExistente;
  bool _guardando = false;
  bool _cargado = false;

  bool get _esEdicion => widget.eventoId != null;

  @override
  void dispose() {
    _nombreController.dispose();
    _paisController.dispose();
    _tematicaController.dispose();
    _direccionController.dispose();
    _lugarController.dispose();
    super.dispose();
  }

  void _precargar(Evento evento) {
    if (_cargado) return;
    _cargado = true;
    _nombreController.text = evento.nombre;
    _paisController.text = evento.pais ?? '';
    _tematicaController.text = evento.tematica ?? '';
    _direccionController.text = evento.direccion ?? '';
    _lugarController.text = evento.lugar ?? '';
    _fecha = evento.fecha;
    _certificacion = evento.certificacionCapacitacion;
    _activo = evento.activo;
    _tipoRegistro = evento.tipoRegistro;
    _imagenUrlExistente = evento.imagenUrl;
  }

  Future<void> _elegirImagen() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _imagenBytes = bytes);
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
      var imagenUrl = _imagenUrlExistente;
      if (_imagenBytes != null) {
        imagenUrl = await ref
            .read(storageRepositoryProvider)
            .subirImagenEvento(_imagenBytes!, 'jpg');
      }

      final evento = Evento(
        id: widget.eventoId ?? '',
        nombre: _nombreController.text.trim(),
        fecha: _fecha,
        pais: _paisController.text.trim(),
        tematica: _tematicaController.text.trim(),
        direccion: _direccionController.text.trim(),
        lugar: _lugarController.text.trim(),
        certificacionCapacitacion: _certificacion,
        activo: _activo,
        imagenUrl: imagenUrl,
        tipoRegistro: _tipoRegistro,
      );

      final repo = ref.read(eventosRepositoryProvider);
      if (_esEdicion) {
        await repo.actualizar(widget.eventoId!, evento.toInsertMap());
      } else {
        await repo.crear(evento);
      }

      ref.invalidate(eventosListProvider);
      if (widget.eventoId != null) {
        ref.invalidate(eventoByIdProvider(widget.eventoId!));
      }

      if (mounted) {
        showAppSnackBar(context, _esEdicion ? 'Evento actualizado.' : 'Evento creado.');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'No se pudo guardar el evento.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar() async {
    final confirmado = await confirmDialog(
      context,
      title: 'Eliminar evento',
      message: 'Esta acción no se puede deshacer. ¿Eliminar el evento y sus registrados?',
      confirmLabel: 'Eliminar',
    );
    if (!confirmado) return;

    try {
      await ref.read(eventosRepositoryProvider).eliminar(widget.eventoId!);
      ref.invalidate(eventosListProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'No se pudo eliminar el evento.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventoAsync = widget.eventoId == null
        ? null
        : ref.watch(eventoByIdProvider(widget.eventoId!));

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
                    GestureDetector(
                      onTap: _elegirImagen,
                      child: Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          image: _imagenBytes != null
                              ? DecorationImage(
                                  image: MemoryImage(_imagenBytes!),
                                  fit: BoxFit.cover)
                              : (_imagenUrlExistente != null
                                  ? DecorationImage(
                                      image: NetworkImage(_imagenUrlExistente!),
                                      fit: BoxFit.cover)
                                  : null),
                        ),
                        child: (_imagenBytes == null && _imagenUrlExistente == null)
                            ? const Center(
                                child: Icon(Icons.add_photo_alternate_outlined,
                                    size: 40, color: AppColors.textSecondary))
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nombreController,
                      decoration: const InputDecoration(labelText: 'Nombre del evento'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
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
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _lugarController,
                      decoration: const InputDecoration(labelText: 'Lugar'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _direccionController,
                      decoration: const InputDecoration(labelText: 'Dirección'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _tematicaController,
                      decoration: const InputDecoration(labelText: 'Temática'),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<TipoRegistroEvento>(
                      initialValue: _tipoRegistro,
                      decoration: const InputDecoration(labelText: 'Tipo de registro'),
                      items: const [
                        DropdownMenuItem(
                          value: TipoRegistroEvento.comercial,
                          child: Text('Comercial'),
                        ),
                        DropdownMenuItem(
                          value: TipoRegistroEvento.cliente,
                          child: Text('Cliente'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _tipoRegistro = value ?? _tipoRegistro),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Requiere certificación / capacitación'),
                      subtitle: const Text('Habilita los campos RUT y patente'),
                      value: _certificacion,
                      onChanged: (v) => setState(() => _certificacion = v),
                    ),
                    if (_esEdicion)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Evento activo'),
                        subtitle: const Text('Los eventos inactivos no reciben autoregistro público'),
                        value: _activo,
                        onChanged: (v) => setState(() => _activo = v),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _guardando ? null : _guardar,
                      child: _guardando
                          ? const ButtonProgress()
                          : Text(_esEdicion ? 'Guardar cambios' : 'Crear evento'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
