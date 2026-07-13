import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/constants/supabase_tables.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/lead.dart';
import '../../../data/offline/sync_queue_service.dart';
import '../../../data/repositories/leads_repository.dart';
import '../../../data/repositories/storage_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/capturador_providers.dart';

enum _CampoVoz { nombre, empresa, cargo, email }

class CrearLeadScreen extends ConsumerStatefulWidget {
  const CrearLeadScreen({super.key, required this.eventoId});

  final String eventoId;

  @override
  ConsumerState<CrearLeadScreen> createState() => _CrearLeadScreenState();
}

class _CrearLeadScreenState extends ConsumerState<CrearLeadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _empresaController = TextEditingController();
  final _cargoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();

  final _speech = stt.SpeechToText();
  bool _speechDisponible = false;
  _CampoVoz? _escuchandoCampo;

  final List<Uint8List> _fotosBytes = [];
  bool _guardando = false;

  static const _maxFotos = 3;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final ok = await _speech.initialize(
      onError: (_) {
        if (mounted) setState(() => _escuchandoCampo = null);
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _escuchandoCampo = null);
        }
      },
    );
    if (mounted) setState(() => _speechDisponible = ok);
  }

  @override
  void dispose() {
    _speech.stop();
    _nombreController.dispose();
    _empresaController.dispose();
    _cargoController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  TextEditingController _controllerDe(_CampoVoz campo) {
    return switch (campo) {
      _CampoVoz.nombre => _nombreController,
      _CampoVoz.empresa => _empresaController,
      _CampoVoz.cargo => _cargoController,
      _CampoVoz.email => _emailController,
    };
  }

  Future<void> _toggleVoz(_CampoVoz campo) async {
    if (!_speechDisponible) {
      showAppSnackBar(
        context,
        'El dictado por voz no está disponible en este dispositivo.',
        isError: true,
      );
      return;
    }

    if (_escuchandoCampo == campo) {
      await _speech.stop();
      setState(() => _escuchandoCampo = null);
      return;
    }

    if (_escuchandoCampo != null) {
      await _speech.stop();
    }

    setState(() => _escuchandoCampo = campo);
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(localeId: 'es_ES'),
      onResult: (result) {
        final texto = result.recognizedWords.trim();
        if (texto.isEmpty) return;
        _controllerDe(campo).text = texto;
        _controllerDe(campo).selection = TextSelection.fromPosition(
          TextPosition(offset: texto.length),
        );
      },
    );
  }

  Future<void> _agregarFoto(ImageSource source) async {
    if (_fotosBytes.length >= _maxFotos) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 70,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _fotosBytes.add(bytes));
  }

  Future<void> _elegirFuenteFoto() async {
    if (_fotosBytes.length >= _maxFotos) {
      showAppSnackBar(context, 'Máximo $_maxFotos fotos.', isError: true);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(ctx);
                _agregarFoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(ctx);
                _agregarFoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _limpiarFormulario() {
    _formKey.currentState?.reset();
    _nombreController.clear();
    _empresaController.clear();
    _cargoController.clear();
    _telefonoController.clear();
    _emailController.clear();
    setState(() => _fotosBytes.clear());
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_escuchandoCampo != null) {
      await _speech.stop();
      setState(() => _escuchandoCampo = null);
    }

    setState(() => _guardando = true);
    final isOnline = ref.read(isOnlineProvider);
    final userId = ref.read(currentPerfilProvider).valueOrNull?.id;

    try {
      final fotosUrls = <String>[];
      if (_fotosBytes.isNotEmpty) {
        if (!isOnline) {
          throw Exception(
            'Las fotos requieren conexión. Guarda el lead sin fotos o reconéctate.',
          );
        }
        final storage = ref.read(storageRepositoryProvider);
        for (final bytes in _fotosBytes) {
          final url = await storage.subirFotoLead(bytes, 'jpg');
          fotosUrls.add(url);
        }
      }

      final lead = Lead(
        id: '',
        eventoId: widget.eventoId,
        nombreCompleto: _nombreController.text.trim(),
        empresa: _empresaController.text.trim(),
        cargo: _cargoController.text.trim().isEmpty
            ? null
            : _cargoController.text.trim(),
        telefono: _telefonoController.text.trim().isEmpty
            ? null
            : _telefonoController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim().toLowerCase(),
        fotosUrls: fotosUrls,
        perfilId: userId,
      );

      if (isOnline) {
        await ref.read(leadsRepositoryProvider).crear(lead);
      } else {
        await ref.read(syncQueueServiceProvider.notifier).enqueueInsert(
              table: SupabaseTables.leads,
              payload: lead.toInsertMap(),
            );
      }

      ref.invalidate(leadsPorEventoProvider(widget.eventoId));

      if (mounted) {
        showAppSnackBar(
          context,
          isOnline
              ? 'Lead guardado.'
              : 'Guardado en modo local. Se subirá solo.',
        );
        _limpiarFormulario();
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _campoConMic({
    required TextEditingController controller,
    required String label,
    required _CampoVoz campo,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    final escuchando = _escuchandoCampo == campo;
    return TextFormField(
      controller: controller,
      enabled: enabled && !escuchando && !_guardando,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: _speechDisponible
            ? IconButton(
                tooltip: escuchando ? 'Detener dictado' : 'Dictar',
                onPressed: _guardando ? null : () => _toggleVoz(campo),
                icon: Icon(
                  escuchando ? Icons.mic : Icons.mic_none_outlined,
                  color: escuchando ? AppColors.error : AppColors.primary,
                ),
              )
            : null,
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventoAsync = ref.watch(eventoLeadByIdProvider(widget.eventoId));

    return AppScaffold(
      titleWidget: eventoAsync.when(
        data: (e) => Text('Capturar · ${e.nombre}', overflow: TextOverflow.ellipsis),
        loading: () => const Text('Capturar lead'),
        error: (_, _) => const Text('Capturar lead'),
      ),
      actions: [
        IconButton(
          tooltip: 'Ver leads',
          icon: const Icon(Icons.list_alt_rounded),
          onPressed: () =>
              context.push(RoutePaths.verLeads(widget.eventoId)),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _campoConMic(
                controller: _nombreController,
                label: 'Nombre completo',
                campo: _CampoVoz.nombre,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 14),
              _campoConMic(
                controller: _empresaController,
                label: 'Empresa',
                campo: _CampoVoz.empresa,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 14),
              _campoConMic(
                controller: _cargoController,
                label: 'Cargo',
                campo: _CampoVoz.cargo,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _telefonoController,
                enabled: !_guardando,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
              const SizedBox(height: 14),
              _campoConMic(
                controller: _emailController,
                label: 'Email',
                campo: _CampoVoz.email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              Text(
                'Fotos (${_fotosBytes.length}/$_maxFotos)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < _fotosBytes.length; i++)
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Image.memory(
                            _fotosBytes[i],
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -8,
                          right: -8,
                          child: IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(4),
                              minimumSize: const Size(28, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            iconSize: 16,
                            onPressed: _guardando
                                ? null
                                : () => setState(() => _fotosBytes.removeAt(i)),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ],
                    ),
                  if (_fotosBytes.length < _maxFotos)
                    InkWell(
                      onTap: _guardando ? null : _elegirFuenteFoto,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.add_a_photo_outlined,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const ButtonProgress()
                    : const Text('Guardar lead'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
