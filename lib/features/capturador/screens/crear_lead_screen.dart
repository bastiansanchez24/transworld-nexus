import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/mascara_contacto.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/evento_hero_banner.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../core/widgets/selector_imagen.dart';
import '../../../data/models/lead.dart';
import '../../../data/models/lead_write_result.dart';
import '../../../data/models/lead_prefill.dart';
import '../../../data/offline/pending_photo_store.dart';
import '../../../data/offline/sync_queue_service.dart';
import '../../../data/repositories/leads_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../externo/providers/externo_dashboard_provider.dart';
import '../providers/capturador_providers.dart';
import '../widgets/foto_lead_identidad.dart';

enum _CampoVoz { nombre, empresa, cargo, email, descripcion }

/// Un campo de contacto queda bloqueado solo si el QR trajo el dato y el rol no
/// puede verlo. En captura manual (sin dato) se escribe con normalidad.
bool _contactoBloqueado(String? prefill, bool puedeVerContacto) {
  return !puedeVerContacto && prefill != null;
}

String? _sinVacios(String valor) {
  final texto = valor.trim();
  return texto.isEmpty ? null : texto;
}

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
  static const _uuid = Uuid();
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
  String? _leadGuardadoPendienteFotoId;

  bool _guardando = false;
  bool _accesoValidado = false;

  /// Contacto que trajo el QR. Quien no puede ver el contacto lo edita con la
  /// máscara a la vista, así que al guardar se envía este valor y no el texto
  /// del campo. Si el QR no trajo nada, el campo queda libre para escribirlo.
  String? _emailPrefill;
  String? _telefonoPrefill;

  /// `null` hasta la primera sincronización, para que el primer valor del rol
  /// siempre se aplique.
  bool? _contactoEnmascarado;

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
    _sincronizarMascaraContacto(
      puedeVerContacto: ref.read(canViewLeadContactDataProvider),
    );
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _validarAccesoExterno(),
    );
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

    final ok =
        eventoReg != null &&
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
      _telefonoPrefill = prefill.telefono;
      _telefonoController.text = prefill.telefono!;
    }
    if (prefill.email != null) {
      _emailPrefill = prefill.email;
      _emailController.text = prefill.email!;
    }
  }

  /// Cambia el contacto precargado entre su valor real y la máscara. Se llama
  /// también cuando el rol se resuelve después del primer frame, así un
  /// administrador nunca queda con la máscara puesta.
  void _sincronizarMascaraContacto({required bool puedeVerContacto}) {
    if (_contactoEnmascarado == !puedeVerContacto) return;
    _contactoEnmascarado = !puedeVerContacto;

    final email = _emailPrefill;
    if (email != null) {
      _emailController.text = puedeVerContacto ? email : enmascararEmail(email);
    }
    final telefono = _telefonoPrefill;
    if (telefono != null) {
      _telefonoController.text = puedeVerContacto
          ? telefono
          : enmascararTelefono(telefono);
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
    // Sin esto la captura en cadena arrastraría el contacto del lead anterior.
    _emailPrefill = null;
    _telefonoPrefill = null;
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

  /// Conserva la foto localmente hasta que el servidor confirme la fila. Así
  /// un duplicado nunca deja archivos huérfanos en Storage.
  Future<List<String>> _resolverFotos({required bool isOnline}) async {
    final bytes = _fotoBytes;
    if (bytes == null) return const [];

    final store = ref.read(pendingPhotoStoreProvider);
    if (store.disponible) return [await store.guardar(bytes)];

    // Web no tiene disco persistente. En línea se conserva el flujo seguro:
    // el repositorio crea primero la fila y recién después sube estos bytes.
    if (isOnline) return const [];
    return const [];
  }

  String? _validarEmail(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return 'Requerido';
    final partes = value.split('@');
    if (partes.length != 2 ||
        partes.first.isEmpty ||
        !partes.last.contains('.') ||
        partes.last.startsWith('.') ||
        partes.last.endsWith('.')) {
      return 'Ingresa un email válido';
    }
    return null;
  }

  void _finalizarFlujoGuardado() {
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
    final puedeVerContacto = perfil?.canViewLeadContactData ?? false;
    Lead? leadPreparado;
    List<String> fotosPreparadas = const [];

    try {
      final pendienteFotoId = _leadGuardadoPendienteFotoId;
      final bytesPendientes = _fotoBytes;
      if (pendienteFotoId != null && bytesPendientes != null) {
        try {
          await ref
              .read(leadsRepositoryProvider)
              .adjuntarFotoBytes(pendienteFotoId, bytesPendientes);
          _leadGuardadoPendienteFotoId = null;
          if (mounted) {
            showAppSnackBar(context, 'Lead y foto guardados.');
            _finalizarFlujoGuardado();
          }
        } catch (_) {
          if (mounted) {
            showAppSnackBar(
              context,
              'Lead guardado; foto pendiente, reintenta',
              isError: true,
            );
          }
        }
        return;
      }

      if (userId == null || userId.isEmpty) {
        throw Exception(
          'No se pudo identificar al usuario capturador. Intenta de nuevo.',
        );
      }
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
      final fotoDescartada =
          _fotoBytes != null &&
          !isOnline &&
          !ref.read(pendingPhotoStoreProvider).disponible;
      final fotos = await _resolverFotos(isOnline: isOnline);
      fotosPreparadas = fotos;

      final lead = Lead(
        id: '',
        eventoId: widget.eventoId,
        nombreCompleto: _nombreController.text.trim(),
        empresa: _empresaController.text.trim(),
        cargo: _cargoController.text.trim().isEmpty
            ? null
            : _cargoController.text.trim(),
        // Un campo bloqueado muestra la máscara: el valor que se guarda es el
        // que trajo el QR.
        telefono: _contactoBloqueado(_telefonoPrefill, puedeVerContacto)
            ? _telefonoPrefill
            : _sinVacios(_telefonoController.text),
        email: _contactoBloqueado(_emailPrefill, puedeVerContacto)
            ? _emailPrefill?.toLowerCase()
            : _sinVacios(_emailController.text)?.toLowerCase(),
        descripcion: _descripcionController.text.trim().isEmpty
            ? null
            : _descripcionController.text.trim(),
        fotosUrls: fotos,
        perfilId: userId,
      );
      leadPreparado = lead;

      LeadWriteResult? result;
      var fotoPendienteDeSync = false;
      if (isOnline) {
        try {
          result = await ref.read(leadsRepositoryProvider).crear(lead);
        } on LeadPhotoPendingException catch (error) {
          result = error.result;
          await ref
              .read(syncQueueServiceProvider.notifier)
              .enqueueUpdate(
                table: SupabaseTables.leads,
                entityId: error.result.leadId,
                changes: {'fotos_urls': error.fotosPendientes},
              );
          fotoPendienteDeSync = true;
        }
      } else {
        await ref
            .read(syncQueueServiceProvider.notifier)
            .enqueueInsert(
              table: SupabaseTables.leads,
              payload: {
                ...lead.toInsertMap(),
                '_requested_lead_id': _uuid.v4(),
              },
            );
      }

      ref.invalidate(leadsPorEventoProvider(widget.eventoId));
      if (perfil?.isExterno == true) {
        ref.invalidate(externoDashboardProvider);
      }

      if (mounted) {
        if (result?.esDuplicado == true) {
          final store = ref.read(pendingPhotoStoreProvider);
          for (final foto in fotos.where(esFotoLocal)) {
            await store.borrar(foto);
          }
          if (!mounted) return;
          showAppSnackBar(context, result!.mensajeDuplicado, isError: true);
          return;
        }
        if (result?.guardado == true &&
            _fotoBytes != null &&
            fotos.isEmpty &&
            isOnline) {
          try {
            await ref
                .read(leadsRepositoryProvider)
                .adjuntarFotoBytes(result!.leadId, _fotoBytes!);
          } catch (_) {
            if (!mounted) return;
            _leadGuardadoPendienteFotoId = result!.leadId;
            showAppSnackBar(
              context,
              'Lead guardado; foto pendiente, reintenta',
              isError: true,
            );
            return;
          }
        }
        if (!mounted) return;
        showAppSnackBar(context, switch ((isOnline, fotoDescartada)) {
          (true, _) when fotoPendienteDeSync =>
            'Lead guardado. La foto se sincronizará automáticamente.',
          (true, _) => 'Lead guardado.',
          (false, true) =>
            'Guardado en modo local, pero sin la foto: se necesita '
                'conexión para adjuntarla.',
          (false, false) => 'Guardado en modo local. Se subirá solo.',
        }, isError: fotoDescartada);
        _finalizarFlujoGuardado();
      }
    } catch (e) {
      if (isOnline && leadPreparado != null && isNetworkTransportError(e)) {
        try {
          await ref
              .read(syncQueueServiceProvider.notifier)
              .enqueueInsert(
                table: SupabaseTables.leads,
                payload: {
                  ...leadPreparado.toInsertMap(),
                  '_requested_lead_id': _uuid.v4(),
                },
              );
          ref.invalidate(leadsPorEventoProvider(widget.eventoId));
          if (mounted) {
            showAppSnackBar(
              context,
              'Sin conexión real. El lead quedó guardado localmente.',
            );
            _finalizarFlujoGuardado();
          }
          return;
        } catch (_) {
          // Continúa al error original y limpia marcadores sin referencia.
        }
      }
      final store = ref.read(pendingPhotoStoreProvider);
      for (final foto in fotosPreparadas.where(esFotoLocal)) {
        await store.borrar(foto);
      }
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

  /// Micrófono de dictado. Sobre la card navy el rojo de "grabando" no se
  /// distingue, así que ahí se usa la lima del brand.
  Widget? _botonVoz(_CampoVoz campo, {bool sobreNavy = false}) {
    if (!_speechDisponible) return null;
    final escuchando = _escuchandoCampo == campo;
    return IconButton(
      tooltip: escuchando ? 'Detener dictado' : 'Dictar',
      onPressed: _guardando ? null : () => _toggleVoz(campo),
      icon: Icon(
        escuchando ? Icons.mic : Icons.mic_none_outlined,
        color: sobreNavy
            ? (escuchando ? AppColors.accent : Colors.white)
            : (escuchando ? AppColors.danger : AppColors.primary),
      ),
    );
  }

  Widget _campoTexto({
    required String label,
    required TextEditingController controller,
    required String hintText,
    _CampoVoz? campoVoz,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool protegido = false,
  }) {
    final escuchando = campoVoz != null && _escuchandoCampo == campoVoz;
    return NexusFormTextField(
      label: label,
      controller: controller,
      hintText: hintText,
      enabled: !escuchando && !_guardando,
      readOnly: protegido,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      helperText: protegido
          ? 'Solo visible para administradores y organizadores'
          : null,
      suffixIcon: protegido
          ? const Icon(
              Symbols.lock_rounded,
              size: 18,
              color: AppColors.textTertiary,
            )
          : (campoVoz == null ? null : _botonVoz(campoVoz)),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(externoEventosAutorizadosIdsProvider, (_, _) {
      if (!_accesoValidado) _validarAccesoExterno();
    });
    // El perfil puede resolverse después del primer frame: al llegar el rol se
    // repinta el contacto precargado con o sin máscara.
    ref.listen(canViewLeadContactDataProvider, (_, puedeVerContacto) {
      if (!mounted) return;
      setState(
        () => _sincronizarMascaraContacto(puedeVerContacto: puedeVerContacto),
      );
    });

    final eventoAsync = ref.watch(eventoLeadByIdProvider(widget.eventoId));
    final puedeVerContacto = ref.watch(canViewLeadContactDataProvider);
    final emailBloqueado = _contactoBloqueado(_emailPrefill, puedeVerContacto);
    final telefonoBloqueado = _contactoBloqueado(
      _telefonoPrefill,
      puedeVerContacto,
    );

    return AppScaffold(
      titleWidget: eventoAsync.when(
        data: (e) =>
            Text('Capturar · ${e.nombre}', overflow: TextOverflow.ellipsis),
        loading: () => const Text('Capturar lead'),
        error: (_, _) => const Text('Capturar lead'),
      ),
      onWillPop: () => confirmDiscardCreate(context),
      body: SingleChildScrollView(
        padding: AppSpacing.form,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (eventoAsync.asData?.value.tieneImagen == true) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: EventoHeroFoto(
                      imagenUrl: eventoAsync.asData!.value.imagenUrl!,
                      velo: 0.28,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              ListenableBuilder(
                listenable: _emailController,
                builder: (context, _) {
                  return PersonaIdentityBanner(
                    nombre: _nombreController.text,
                    email: _emailController.text,
                    nombreController: _nombreController,
                    nombreHint: 'Ej. María González',
                    nombreEnabled:
                        !_guardando && _escuchandoCampo != _CampoVoz.nombre,
                    nombreValidator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    nombreSuffix: _botonVoz(_CampoVoz.nombre, sobreNavy: true),
                    leading: FotoLeadAvatar(
                      bytes: _fotoBytes,
                      enabled: !_guardando,
                      onElegir: _elegirFoto,
                      onQuitar: _fotoBytes == null
                          ? null
                          : () => setState(() => _fotoBytes = null),
                    ),
                  );
                },
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
                protegido: telefonoBloqueado,
              ),
              const SizedBox(height: 14),
              _campoTexto(
                label: 'Email',
                controller: _emailController,
                hintText: 'correo@empresa.com',
                campoVoz: emailBloqueado ? null : _CampoVoz.email,
                keyboardType: TextInputType.emailAddress,
                validator: emailBloqueado ? null : _validarEmail,
                protegido: emailBloqueado,
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
