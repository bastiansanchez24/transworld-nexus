import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/constants/supabase_tables.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../core/widgets/selector_imagen.dart';
import '../../../data/models/lead.dart';
import '../../../data/models/lead_prefill.dart';
import '../../../data/offline/pending_photo_store.dart';
import '../../../data/offline/sync_queue_service.dart';
import '../../../data/repositories/leads_repository.dart';
import '../../../data/repositories/storage_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/capturador_providers.dart';

enum _CampoVoz { nombre, empresa, cargo, email, descripcion }

class CrearLeadScreen extends ConsumerStatefulWidget {
  const CrearLeadScreen({
    super.key,
    required this.eventoId,
    this.prefill,
    this.eventoRegistroId,
  });

  final String eventoId;
  final LeadPrefill? prefill;

  /// Evento de registro de origen (flujo QR). Tras guardar se hace pop
  /// al escáner en lugar de reemplazar el stack.
  final String? eventoRegistroId;

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
  final _descripcionController = TextEditingController();

  final _speech = stt.SpeechToText();
  bool _speechDisponible = false;
  _CampoVoz? _escuchandoCampo;

  /// Foto ya comprimida, todavía en memoria. Se sube (o se deja en disco, si
  /// no hay red) recién al guardar el lead.
  Uint8List? _fotoBytes;

  bool _guardando = false;
  bool _accesoValidado = false;

  /// `null` = junction aún cargando; set vacío = sin autorización usable.
  Set<String>? _idsPermitidosExterno() {
    final autorizados = ref.read(externoEventosAutorizadosIdsProvider);
    if (autorizados == null) return null;
    if (autorizados.isNotEmpty) return autorizados;
    final activo = ref.read(externoEventoIdProvider);
    if (activo == null || activo.isEmpty) return {};
    return {activo};
  }

  @override
  void initState() {
    super.initState();
    _aplicarPrefill();
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) => _validarAccesoExterno());
  }

  void _validarAccesoExterno() {
    if (!mounted || _accesoValidado) return;
    final perfil = ref.read(currentPerfilProvider).valueOrNull;
    if (perfil == null || !perfil.isExterno) {
      _accesoValidado = true;
      return;
    }

    final eventoReg = widget.eventoRegistroId;
    final permitidos = _idsPermitidosExterno();
    if (permitidos == null) {
      return; // reintentará vía ref.listen en build
    }

    final ok = eventoReg != null &&
        eventoReg.isNotEmpty &&
        permitidos.contains(eventoReg);

    _accesoValidado = true;
    if (ok) return;

    final activo = ref.read(externoEventoIdProvider);
    final destino = activo != null && activo.isNotEmpty
        ? RoutePaths.externoEvento(activo)
        : RoutePaths.eventoFinalizado;
    context.go(destino);
  }

  void _aplicarPrefill() {
    final prefill = widget.prefill;
    if (prefill == null) return;
    if (prefill.nombreCompleto != null) {
      _nombreController.text = prefill.nombreCompleto!;
    }
    if (prefill.empresa != null) {
      _empresaController.text = prefill.empresa!;
    }
    if (prefill.cargo != null) {
      _cargoController.text = prefill.cargo!;
    }
    if (prefill.telefono != null) {
      _telefonoController.text = prefill.telefono!;
    }
    if (prefill.email != null) {
      _emailController.text = prefill.email!;
    }
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
    _descripcionController.dispose();
    super.dispose();
  }

  TextEditingController _controllerDe(_CampoVoz campo) {
    return switch (campo) {
      _CampoVoz.nombre => _nombreController,
      _CampoVoz.empresa => _empresaController,
      _CampoVoz.cargo => _cargoController,
      _CampoVoz.email => _emailController,
      _CampoVoz.descripcion => _descripcionController,
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

  void _limpiarFormulario() {
    _formKey.currentState?.reset();
    _nombreController.clear();
    _empresaController.clear();
    _cargoController.clear();
    _telefonoController.clear();
    _emailController.clear();
    _descripcionController.clear();
    // Tras guardar se sigue capturando en cadena: si la foto no se limpia,
    // el siguiente lead se llevaría la del anterior.
    _fotoBytes = null;
  }

  Future<void> _elegirFoto() async {
    final bytes = await elegirImagenComprimida(
      context,
      recorteProporcion: kProporcionFotoLead,
    );
    if (bytes == null || !mounted) return;
    setState(() => _fotoBytes = bytes);
  }

  /// Resuelve la foto a lo que va en `fotos_urls`: una URL pública si hay
  /// red, o un marcador `local_foto://` que la cola subirá al reconectar.
  Future<List<String>> _resolverFotos({required bool isOnline}) async {
    final bytes = _fotoBytes;
    if (bytes == null) return const [];

    if (isOnline) {
      return [
        await ref.read(storageRepositoryProvider).subirFotoLead(bytes, 'jpg'),
      ];
    }

    final store = ref.read(pendingPhotoStoreProvider);
    if (!store.disponible) return const [];
    return [await store.guardar(bytes)];
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_escuchandoCampo != null) {
      await _speech.stop();
      setState(() => _escuchandoCampo = null);
    }

    setState(() => _guardando = true);
    final isOnline = ref.read(isOnlineProvider);
    final perfil = ref.read(currentPerfilProvider).valueOrNull;
    final userId = perfil?.id;

    try {
      if (perfil?.isExterno == true) {
        final eventoReg = widget.eventoRegistroId;
        final permitidos = _idsPermitidosExterno();
        if (permitidos == null) {
          throw Exception(
            'Aún se están cargando tus eventos autorizados. Intenta de nuevo.',
          );
        }
        if (eventoReg == null || !permitidos.contains(eventoReg)) {
          throw Exception(
            'No estás autorizado para capturar leads en este evento.',
          );
        }
      }

      // En web no hay dónde dejar la foto esperando a que vuelva la red, así
      // que el lead se guarda sin ella y hay que decirlo.
      final fotoDescartada = _fotoBytes != null &&
          !isOnline &&
          !ref.read(pendingPhotoStoreProvider).disponible;
      final fotos = await _resolverFotos(isOnline: isOnline);

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
        descripcion: _descripcionController.text.trim().isEmpty
            ? null
            : _descripcionController.text.trim(),
        fotosUrls: fotos,
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
          switch ((isOnline, fotoDescartada)) {
            (true, _) => 'Lead guardado.',
            (false, true) =>
              'Guardado en modo local, pero sin la foto: se necesita '
                  'conexión para adjuntarla.',
            (false, false) => 'Guardado en modo local. Se subirá solo.',
          },
          isError: fotoDescartada,
        );
        // Volver al escáner con pop (no go): go reemplaza el stack y deja
        // el QR sin historial → la X no cierra y el atrás sale de la app.
        final eventoRegistroId = widget.eventoRegistroId;
        if (eventoRegistroId != null) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(RoutePaths.acreditarQr(eventoRegistroId));
          }
        } else {
          _limpiarFormulario();
        }
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

  Widget _campoTexto({
    required String label,
    required TextEditingController controller,
    required String hintText,
    _CampoVoz? campoVoz,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final escuchando = campoVoz != null && _escuchandoCampo == campoVoz;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: !escuchando && !_guardando,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            alignLabelWithHint: maxLines > 1,
            suffixIcon: campoVoz != null && _speechDisponible
                ? IconButton(
                    tooltip: escuchando ? 'Detener dictado' : 'Dictar',
                    onPressed: _guardando ? null : () => _toggleVoz(campoVoz),
                    icon: Icon(
                      escuchando ? Icons.mic : Icons.mic_none_outlined,
                      color: escuchando ? AppColors.danger : AppColors.primary,
                    ),
                  )
                : null,
          ),
          validator: validator,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(externoEventosAutorizadosIdsProvider, (_, _) {
      if (!_accesoValidado) _validarAccesoExterno();
    });

    final eventoAsync = ref.watch(eventoLeadByIdProvider(widget.eventoId));

    return AppScaffold(
      titleWidget: eventoAsync.when(
        data: (e) => Text(
          'Capturar · ${e.nombre}',
          overflow: TextOverflow.ellipsis,
        ),
        loading: () => const Text('Capturar lead'),
        error: (_, _) => const Text('Capturar lead'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FieldLabel('Foto'),
              const SizedBox(height: 6),
              SelectorImagen(
                bytes: _fotoBytes,
                enabled: !_guardando,
                aspectRatio: kProporcionFotoLead,
                anchoMaximo: kAnchoSelectorFotoLead,
                etiquetaVacio: 'Agregar foto del lead',
                onElegir: _elegirFoto,
                onQuitar: _fotoBytes == null
                    ? null
                    : () => setState(() => _fotoBytes = null),
              ),
              const SizedBox(height: 14),
              _campoTexto(
                label: 'Nombre completo',
                controller: _nombreController,
                hintText: 'Ej. María González',
                campoVoz: _CampoVoz.nombre,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 14),
              _campoTexto(
                label: 'Empresa',
                controller: _empresaController,
                hintText: 'Ej. Transworld',
                campoVoz: _CampoVoz.empresa,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 14),
              _campoTexto(
                label: 'Cargo',
                controller: _cargoController,
                hintText: 'Ej. Gerente comercial',
                campoVoz: _CampoVoz.cargo,
              ),
              const SizedBox(height: 14),
              _campoTexto(
                label: 'Teléfono',
                controller: _telefonoController,
                hintText: '+56 9 1234 5678',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              _campoTexto(
                label: 'Email',
                controller: _emailController,
                hintText: 'correo@empresa.com',
                campoVoz: _CampoVoz.email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              _campoTexto(
                label: 'Descripción',
                controller: _descripcionController,
                hintText: 'Notas u observaciones del lead',
                campoVoz: _CampoVoz.descripcion,
                keyboardType: TextInputType.multiline,
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              PrimaryGradientButton(
                label: 'Guardar lead',
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
