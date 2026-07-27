import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/capturar_lead_route_extra.dart';
import '../../../data/models/lead_prefill.dart';
import '../../../data/models/registrado.dart';
import '../../../data/offline/sync_queue_service.dart';
import '../../../data/repositories/registrados_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../capturador/services/campana_desde_evento_service.dart';
import '../../eventos/providers/eventos_providers.dart';
import '../../registrados/providers/registrados_providers.dart';
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
        return await ref
            .read(registradosPorEventoProvider(widget.eventoId).future);
      } catch (_) {
        return [];
      }
    }
    return async.valueOrNull ?? [];
  }

  Future<Registrado?> _resolverRegistrado(String registradoId) async {
    final registrados = await _listaAsistentes();
    final enCache = registrados
        .where((r) => r.id.toLowerCase() == registradoId)
        .firstOrNull;
    if (enCache != null) return enCache;

    if (!ref.read(isOnlineProvider)) return null;

    return ref
        .read(registradosRepositoryProvider)
        .obtenerPorIdEnEvento(registradoId, widget.eventoId);
  }

  Future<void> _acreditar(Registrado registrado) async {
    final userId = ref.read(currentPerfilProvider).valueOrNull?.id;
    final isOnline = ref.read(isOnlineProvider);
    if (isOnline && !registrado.pendienteDeSincronizar) {
      await ref
          .read(registradosRepositoryProvider)
          .acreditar(registrado.id, acreditadoPorId: userId ?? '');
    } else {
      await ref.read(syncQueueServiceProvider.notifier).enqueueUpdate(
            table: 'registrados',
            entityId: registrado.id,
            changes: {'acreditado': true},
          );
    }
    ref.invalidate(registradosPorEventoProvider(widget.eventoId));
  }

  Future<void> _acreditarSiConfirmaParaLead(Registrado registrado) async {
    if (registrado.acreditado) return;

    if (!mounted) return;
    final confirmar = await confirmDialog(
      context,
      title: 'Acreditar asistente',
      message:
          '${registrado.nombreCompleto} aún no está acreditado/a.\n\n¿Deseas acreditarlo/a antes de capturar el lead?',
      confirmLabel: 'Acreditar',
    );
    if (!confirmar || !mounted) return;

    await _acreditar(registrado);
  }

  Future<void> _navegarACaptura(Registrado registrado) async {
    final evento = await ref.read(eventoByIdProvider(widget.eventoId).future);
    final campana = await obtenerOCrearCampanaDesdeEvento(ref, evento);

    if (!mounted) return;
    await _scanner.pauseCamera();
    if (!mounted) return;
    await context.push(
      RoutePaths.capturarLead(
        campana.id,
        desdeEvento: widget.eventoId,
      ),
      extra: CapturarLeadRouteExtra(
        prefill: LeadPrefill.fromRegistrado(registrado),
        eventoRegistroId: widget.eventoId,
      ),
    );
    if (!mounted) return;
    // Si el usuario vuelve (guardar o cancelar), reanudar cámara y escaneo.
    await _scanner.resumeCamera();
    _scanner.resumeScanning();
  }

  Future<void> _procesarAcreditar(Registrado registrado) async {
    if (registrado.acreditado) {
      _scanner.showFeedback(
        '${registrado.nombreCompleto} ya había ingresado.',
        isError: false,
      );
      return;
    }

    if (!mounted) return;
    final confirmar = await confirmDialog(
      context,
      title: 'Acreditar asistente',
      message:
          'Se detectó a ${registrado.nombreCompleto}.\n\n¿Deseas acreditar a esta persona?',
      confirmLabel: 'Acreditar',
    );
    if (!confirmar || !mounted) {
      _scanner.resumeScanning(delay: const Duration(seconds: 2));
      return;
    }

    await _acreditar(registrado);
    _scanner.showFeedback(
      'Bienvenido/a ${registrado.nombreCompleto}',
      isError: false,
    );
  }

  Future<void> _procesarCapturarLead(Registrado registrado) async {
    await _acreditarSiConfirmaParaLead(registrado);
    if (!mounted) return;
    await _navegarACaptura(registrado);
  }

  void _cerrarEscaner() {
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
    final registradosAsync =
        ref.read(registradosPorEventoProvider(widget.eventoId));
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
    // Precarga asistentes sin reconstruir el preview de cámara.
    ref.watch(registradosPorEventoProvider(widget.eventoId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _cerrarEscaner();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ScannerView(
          controller: _scanner,
          onClose: _cerrarEscaner,
        ),
      ),
    );
  }
}
