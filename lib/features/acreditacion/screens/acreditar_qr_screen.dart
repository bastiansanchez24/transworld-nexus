import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/network/offline_guard.dart';
import '../../../core/router/route_paths.dart';
import '../../../data/models/capturar_lead_route_extra.dart';
import '../../../data/models/lead_existente.dart';
import '../../../data/models/lead_prefill.dart';
import '../../../data/models/registrado.dart';
import '../../../data/offline/offline_read_cache.dart';
import '../../../data/repositories/leads_repository.dart';
import '../../../data/repositories/registrados_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../capturador/lead_comentario_flujo.dart';
import '../../capturador/providers/capturador_providers.dart';
import '../../capturador/services/evento_lead_interno_service.dart';
import '../../eventos/providers/eventos_providers.dart';
import '../../registrados/providers/registrados_providers.dart';
import '../acreditacion_sesion_lock.dart';
import '../scanner/qr_scanner_service.dart';
import '../scanner/scanner_controller.dart';
import '../scanner/widgets/scanner_view.dart';

/// Pantalla de dominio: acredita o captura lead tras un QR.
///
/// La UI de cámara vive en [ScannerView]; esta pantalla solo orquesta
/// reglas de negocio sobre el resultado del [ScannerController].
class AcreditarQrScreen extends ConsumerStatefulWidget {
  const AcreditarQrScreen({super.key, required this.eventoId});

  final String eventoId;

  @override
  ConsumerState<AcreditarQrScreen> createState() => _AcreditarQrScreenState();
}

class _AcreditarQrScreenState extends ConsumerState<AcreditarQrScreen>
    with WidgetsBindingObserver {
  late final ScannerController _scanner;
  final AcreditacionSesionLock _sesion = AcreditacionSesionLock();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanner = ScannerController(onCodeDetected: _onCodeDetected);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scanner.initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanner.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Solo paused/resumed: `inactive` dispara con diálogos de permiso del OS
    // y provoca stop/start concurrentes → CAMERA_ERROR en release.
    switch (state) {
      case AppLifecycleState.resumed:
        // La ruta puede seguir montada bajo otra pantalla (p. ej. capturar lead).
        if (!mounted) return;
        if (ModalRoute.of(context)?.isCurrent != true) return;
        _scanner.resumeCamera();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _scanner.pauseCamera();
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<List<Registrado>> _listaAsistentes() async {
    final async = ref.read(registradosPorEventoProvider(widget.eventoId));
    if (async.hasValue) return async.requireValue;
    if (async.isLoading) {
      try {
        return await ref.read(
          registradosPorEventoProvider(widget.eventoId).future,
        );
      } catch (_) {
        return [];
      }
    }
    return async.valueOrNull ?? [];
  }

  Future<Registrado?> _resolverRegistrado(String registradoId) async {
    final id = registradoId.toLowerCase();
    final registrados = await _listaAsistentes();
    final enCache = registrados
        .where((r) => r.id.toLowerCase() == id)
        .firstOrNull;

    return resolverRegistradoParaAcreditacion(
      hayRed: ref.read(isOnlineProvider),
      enCache: enCache,
      obtenerDelServidor: () => ref
          .read(registradosRepositoryProvider)
          .obtenerPorIdEnEvento(registradoId, widget.eventoId),
      escribirCache: (fresco) async {
        await ref
            .read(offlineReadCacheProvider)
            .parchearFila(
              tabla: SupabaseTables.registrados,
              eventoId: widget.eventoId,
              id: fresco.id,
              cambios: fresco.toCacheMap(),
            );
      },
    );
  }

  bool _yaEstaAcreditado(Registrado registrado) {
    return _sesion.yaEstaAcreditado(registrado);
  }

  Future<void> _acreditar(Registrado registrado) async {
    final userId = ref.read(currentPerfilProvider).valueOrNull?.id.trim();
    if (userId == null || userId.isEmpty) {
      throw Exception(
        'No se pudo identificar al usuario acreditador. Intenta de nuevo.',
      );
    }

    // Evita repetir el UPDATE si el mismo QR sigue en cuadro antes de que el
    // provider invalidado alcance a devolver la acreditación actualizada.
    _sesion.marcarEnVuelo(registrado.id);
    try {
      await persistirAcreditacion(
        ref,
        registrado: registrado,
        acreditado: true,
        acreditadoPorId: userId,
      );
    } catch (_) {
      _sesion.sincronizarConLista([registrado]);
      rethrow;
    }
  }

  Future<void> _acreditarSiEsNecesarioParaLead(Registrado registrado) async {
    if (_yaEstaAcreditado(registrado)) return;
    await _acreditar(registrado);
  }

  Future<void> _navegarACaptura(Registrado registrado) async {
    final evento = await ref.read(eventoByIdProvider(widget.eventoId).future);
    final eventoLead = await obtenerOCrearEventoLeadInterno(ref, evento);

    if (!mounted) return;
    await _scanner.pauseCamera();
    if (!mounted) return;
    await context.push(
      RoutePaths.capturarLead(eventoLead.id, desdeEvento: widget.eventoId),
      extra: CapturarLeadRouteExtra(
        prefill: LeadPrefill.fromRegistrado(registrado),
        eventoRegistroId: widget.eventoId,
      ),
    );
    if (!mounted) return;
    await _scanner.resumeCamera();
    _scanner.resumeScanning();
  }

  Future<LeadExistente?> _buscarLeadExistente(
    String eventoLeadId,
    String? email,
  ) async {
    final perfilId = ref.read(currentPerfilProvider).valueOrNull?.id;
    try {
      final enCache = await ref.read(
        leadsPorEventoProvider(eventoLeadId).future,
      );
      final local = leadExistenteEnLista(enCache, email, perfilId: perfilId);
      if (local != null) return local;
    } catch (_) {
      // Sin caché ni red se sigue al RPC o al formulario.
    }

    if (!ref.read(isOnlineProvider)) return null;
    final texto = email?.trim() ?? '';
    if (texto.isEmpty) return null;
    return ref
        .read(leadsRepositoryProvider)
        .buscarPorEmail(eventoId: eventoLeadId, email: texto);
  }

  Future<void> _procesarAcreditar(Registrado registrado) async {
    if (_yaEstaAcreditado(registrado)) {
      _scanner.showFeedback(
        '${registrado.nombreCompleto} ya había ingresado.',
        isError: false,
      );
      return;
    }

    await _acreditar(registrado);
    _scanner.showFeedback(
      'Bienvenido/a ${registrado.nombreCompleto}',
      isError: false,
    );
  }

  Future<void> _procesarCapturarLead(Registrado registrado) async {
    await _acreditarSiEsNecesarioParaLead(registrado);
    if (!mounted) return;

    final evento = await ref.read(eventoByIdProvider(widget.eventoId).future);
    final eventoLead = await obtenerOCrearEventoLeadInterno(ref, evento);
    final existente = await _buscarLeadExistente(
      eventoLead.id,
      registrado.email,
    );
    if (!mounted) return;

    if (existente != null) {
      _scanner.holdScanning();
      final comentar = await confirmarAgregarComentarioLead(context);
      if (!mounted) return;
      if (comentar) {
        if (!requireOnline(context, ref)) {
          _scanner.resumeScanning();
          return;
        }
        await _scanner.pauseCamera();
        if (!mounted) return;
        await irAComentariosLead(
          context,
          ref,
          eventoId: eventoLead.id,
          leadId: existente.leadId,
          desdeEvento: widget.eventoId,
        );
        if (!mounted) return;
        await _scanner.resumeCamera();
      }
      _scanner.resumeScanning();
      return;
    }

    await _navegarACaptura(registrado);
  }

  bool _cerrando = false;

  Future<void> _cerrarEscaner() async {
    if (_cerrando) return;
    _cerrando = true;
    // Hay que cortar el MediaStream *antes* de desmontar el <video>;
    // si no, en web el indicador de cámara queda encendido.
    await _scanner.stopCamera();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
      return;
    }
    // Fallback si el stack quedó sin historial (p. ej. un go previo).
    final isExterno =
        ref.read(currentPerfilProvider).valueOrNull?.isExterno ?? false;
    context.go(
      isExterno
          ? RoutePaths.externoEvento(widget.eventoId)
          : RoutePaths.usarEvento(widget.eventoId),
    );
  }

  Future<void> _onCodeDetected(QrScanDecode decode) async {
    final registradosAsync = ref.read(
      registradosPorEventoProvider(widget.eventoId),
    );
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline && registradosAsync.isLoading) {
      _scanner.showFeedback(
        'Espera a que carguen los asistentes (modo offline).',
        isError: true,
      );
      return;
    }

    try {
      if (!decode.isValid) {
        final preview = decode.rawText == null
            ? '(vacío)'
            : (decode.rawText!.length > 40
                  ? '${decode.rawText!.substring(0, 40)}…'
                  : decode.rawText!);
        _scanner.showFeedback(
          'No se pudo leer el QR. Datos detectados: $preview',
          isError: true,
        );
        return;
      }

      final registrado = await _resolverRegistrado(decode.registradoId!);

      if (registrado == null) {
        _scanner.showFeedback(
          'Código no válido o no pertenece a este evento.',
          isError: true,
        );
        return;
      }

      if (_scanner.captureLeadMode) {
        await _procesarCapturarLead(registrado);
      } else {
        await _procesarAcreditar(registrado);
      }
    } catch (e) {
      _scanner.showFeedback(
        _scanner.captureLeadMode
            ? e.toString().replaceFirst('Exception: ', '')
            : 'No se pudo acreditar. Intenta de nuevo.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(registradosPorEventoProvider(widget.eventoId), (_, next) {
      final lista = next.valueOrNull;
      if (lista == null) return;
      _sesion.sincronizarConLista(lista);
    });
    // Precarga asistentes sin reconstruir el preview de cámara.
    ref.watch(registradosPorEventoProvider(widget.eventoId));

    return PopScope(
      // El gesto iOS de deslizar atrás exige canPop: el cierre (botón o
      // swipe) corta la cámara en dispose / [_cerrarEscaner].
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _cerrarEscaner();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ScannerView(controller: _scanner, onClose: _cerrarEscaner),
      ),
    );
  }
}

/// Con red pide esa fila al servidor; sin red (o si el GET falla) usa el padrón
/// local. Así el flag `acreditado` no se decide con una copia stale.
@visibleForTesting
Future<Registrado?> resolverRegistradoParaAcreditacion({
  required bool hayRed,
  required Registrado? enCache,
  required Future<Registrado?> Function() obtenerDelServidor,
  required Future<void> Function(Registrado fresco) escribirCache,
}) async {
  if (!hayRed) return enCache;
  try {
    final fresco = await obtenerDelServidor();
    if (fresco == null) return enCache;
    await escribirCache(fresco);
    return fresco;
  } catch (_) {
    return enCache;
  }
}
