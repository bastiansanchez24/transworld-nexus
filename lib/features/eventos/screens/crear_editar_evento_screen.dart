import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../core/widgets/nexus_toast.dart';
import '../../../core/widgets/require_permission.dart';
import '../../../data/models/evento.dart';
import '../../../data/repositories/eventos_repository.dart';
import '../../../data/repositories/storage_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/eventos_providers.dart';

/// Crear o editar un evento. Disponible para cualquier usuario autenticado.
class CrearEditarEventoScreen extends StatelessWidget {
  const CrearEditarEventoScreen({super.key, this.eventoId});

  final String? eventoId;

  @override
  Widget build(BuildContext context) {
    return RequirePermission(
      allowed: (p) => p.canCreateContent,
      deniedMessage:
          'Solo administradores y organizadores pueden crear o editar eventos.',
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
        if (_esEdicion) {
          NexusToast.show(context, 'Evento actualizado.');
        } else {
          NexusToast.show(context, 'Evento creado correctamente');
        }
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
      ref.invalidate(eventoByIdProvider(widget.eventoId!));
      if (mounted) context.go(RoutePaths.eventos);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'No se pudo eliminar el evento.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = ref.watch(isAdminProvider);
    final eventoAsync = widget.eventoId == null
        ? null
        : ref.watch(eventoByIdProvider(widget.eventoId!));

    if (eventoAsync != null) {
      eventoAsync.whenData(_precargar);
    }

    return AppScaffold(
      title: _esEdicion ? 'Editar evento' : 'Nuevo evento',
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
                    _ImagenDropZone(
                      imagenBytes: _imagenBytes,
                      imagenUrl: _imagenUrlExistente,
                      onTap: _elegirImagen,
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel('Nombre'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nombreController,
                      decoration: const InputDecoration(
                        hintText: 'Ej. Taller ALTAI 2026',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel('Fecha'),
                    const SizedBox(height: 6),
                    _FechaPickerRow(
                      fecha: _fecha,
                      onTap: _elegirFecha,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _FieldLabel('País'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _paisController,
                                decoration: const InputDecoration(
                                  hintText: 'Chile',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _FieldLabel('Lugar'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _lugarController,
                                decoration: const InputDecoration(
                                  hintText: 'Hotel…',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel('Dirección'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _direccionController,
                      decoration: const InputDecoration(
                        hintText: 'Av. Vitacura 2885',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel('Temática'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _tematicaController,
                      decoration: const InputDecoration(
                        hintText: 'Ej. Telecomunicaciones',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel('Tipo de registro'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<TipoRegistroEvento>(
                      initialValue: _tipoRegistro,
                      decoration: const InputDecoration(),
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
                    const SizedBox(height: 14),
                    _ToggleCard(
                      title: 'Requiere certificación',
                      subtitle: 'Habilita los campos RUT y patente',
                      value: _certificacion,
                      onChanged: (v) => setState(() => _certificacion = v),
                    ),
                    if (_esEdicion) ...[
                      const SizedBox(height: 14),
                      _ToggleCard(
                        title: 'Evento activo',
                        subtitle:
                            'Los eventos inactivos no reciben autoregistro público',
                        value: _activo,
                        onChanged: (v) => setState(() => _activo = v),
                      ),
                    ],
                    const SizedBox(height: 20),
                    PrimaryGradientButton(
                      label: _esEdicion ? 'Guardar' : 'Crear evento',
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

class _ImagenDropZone extends StatelessWidget {
  const _ImagenDropZone({
    required this.imagenBytes,
    required this.imagenUrl,
    required this.onTap,
  });

  final Uint8List? imagenBytes;
  final String? imagenUrl;
  final VoidCallback onTap;

  bool get _tieneImagen => imagenBytes != null || imagenUrl != null;

  @override
  Widget build(BuildContext context) {
    if (_tieneImagen) {
      return GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: SizedBox(
            height: 150,
            width: double.infinity,
            child: imagenBytes != null
                ? Image.memory(imagenBytes!, fit: BoxFit.cover)
                : Image.network(imagenUrl!, fit: BoxFit.cover),
          ),
        ),
      );
    }

    return DashedBorderBox(
      height: 150,
      onTap: onTap,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Symbols.add_photo_alternate_rounded,
            size: 30,
            color: AppColors.primary,
            fill: 1,
          ),
          SizedBox(height: 8),
          Text(
            'Agregar imagen del evento',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FechaPickerRow extends StatelessWidget {
  const _FechaPickerRow({required this.fecha, required this.onTap});

  final DateTime fecha;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('dd/MM/yyyy').format(fecha),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const Icon(
                Symbols.calendar_today_rounded,
                size: 19,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
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
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
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
        ),
      ),
    );
  }
}
