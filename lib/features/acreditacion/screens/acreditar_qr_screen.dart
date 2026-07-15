import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/registrado.dart';
import '../../../data/offline/sync_queue_service.dart';
import '../../../data/repositories/registrados_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../registrados/providers/registrados_providers.dart';
import '../qr_codigo_parser.dart';
import '../widgets/qr_scan_overlay.dart';

/// Escaneo de QR para acreditación rápida. El QR de cada asistente codifica
/// simplemente su `registrados.id`. Al detectar un código válido se pide
/// confirmación antes de acreditar. Funciona igual online u offline: el
/// cambio se aplica localmente contra la lista ya cacheada por
/// [registradosPorEventoProvider] y se encola con la misma cola unificada
/// que usa el resto de la app (ver Sección 17.3 de la auditoría — acá no
/// hay una segunda cola paralela como en el proyecto legado).
///
/// Nota: usa [Scaffold] (no AppScaffold) porque el visor de cámara necesita
/// pantalla completa negra sin header Nexus.
class AcreditarQrScreen extends ConsumerStatefulWidget {
  const AcreditarQrScreen({super.key, required this.eventoId});

  final String eventoId;

  @override
  ConsumerState<AcreditarQrScreen> createState() => _AcreditarQrScreenState();
}

class _AcreditarQrScreenState extends ConsumerState<AcreditarQrScreen> {
  final _controller = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    // `noDuplicates` en web deja el escáner bloqueado tras el primer intento fallido.
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 500,
  );
  bool _procesando = false;
  String? _ultimoMensaje;
  bool _ultimoEsError = false;
  Rect? _scanWindow;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<List<Registrado>> _listaAsistentes() async {
    final async = ref.read(registradosPorEventoProvider(widget.eventoId));
    if (async.hasValue) return async.requireValue;
    if (async.isLoading) {
      try {
        return await ref.read(registradosPorEventoProvider(widget.eventoId).future);
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

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_procesando) return;
    if (capture.barcodes.isEmpty) return;

    final registradosAsync = ref.read(registradosPorEventoProvider(widget.eventoId));
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline && registradosAsync.isLoading) {
      _mostrarResultado(
        'Espera a que carguen los asistentes (modo offline).',
        esError: true,
      );
      return;
    }

    setState(() => _procesando = true);

    final textoLeido = textoLeidoDeCaptura(capture);
    final registradoId = extraerRegistradoIdDeCaptura(capture);

    try {
      if (registradoId == null) {
        final preview = textoLeido == null
            ? '(vacío)'
            : (textoLeido.length > 40 ? '${textoLeido.substring(0, 40)}…' : textoLeido);
        _mostrarResultado(
          'No se pudo leer el QR. Datos detectados: $preview',
          esError: true,
        );
        return;
      }

      final registrado = await _resolverRegistrado(registradoId);

      if (registrado == null) {
        _mostrarResultado('Código no válido o no pertenece a este evento.', esError: true);
        return;
      }
      if (registrado.acreditado) {
        _mostrarResultado('${registrado.nombreCompleto} ya había ingresado.', esError: false);
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
        // Evita que el mismo QR vuelva a abrir el diálogo de inmediato.
        await Future.delayed(const Duration(seconds: 2));
        return;
      }

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
      _mostrarResultado('Bienvenido/a ${registrado.nombreCompleto}', esError: false);
    } catch (e) {
      _mostrarResultado('No se pudo acreditar. Intenta de nuevo.', esError: true);
    } finally {
      if (mounted && _ultimoMensaje == null) {
        setState(() => _procesando = false);
      }
    }
  }

  void _mostrarResultado(String mensaje, {required bool esError}) {
    setState(() {
      _ultimoMensaje = mensaje;
      _ultimoEsError = esError;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _ultimoMensaje = null;
          _procesando = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Precarga la lista al abrir la pantalla; antes solo se leía al escanear
    // y el provider autoDispose podía devolver [] si aún estaba cargando.
    final registradosAsync = ref.watch(registradosPorEventoProvider(widget.eventoId));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            tapToFocus: !kIsWeb,
            scanWindow: kIsWeb ? null : _scanWindow,
            overlayBuilder: (context, constraints) {
              final scanWindow = computeQrScanWindow(constraints);
              if (_scanWindow != scanWindow) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _scanWindow = scanWindow);
                });
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (kIsWeb)
                    QrScanDimOverlay(scanWindow: scanWindow)
                  else
                    ScanWindowOverlay(
                      controller: _controller,
                      scanWindow: scanWindow,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderWidth: 0,
                    ),
                  QrScanCornerFrame(scanWindow: scanWindow),
                ],
              );
            },
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Symbols.videocam_off_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      error.errorCode.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    if (kIsWeb) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'En navegador necesitas permitir la cámara y usar HTTPS. '
                        'Para acreditación en terreno, preferir Android o iOS.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Symbols.close_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        onPressed: () => context.pop(),
                      ),
                      const Expanded(
                        child: Text(
                          'Escanear QR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (!kIsWeb)
                        IconButton(
                          icon: const Icon(
                            Symbols.flash_on_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => _controller.toggleTorch(),
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),
                if (kIsWeb)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Text(
                      'Modo navegador: el QR debe mostrarse en otro dispositivo o impreso. '
                      'No puedes escanear un QR en la misma pantalla.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (registradosAsync.isLoading)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Cargando asistentes...',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                else if (registradosAsync.hasError)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ErrorView(
                      message: 'No se pudo cargar la lista de asistentes.',
                      onRetry: () => ref.invalidate(registradosPorEventoProvider(widget.eventoId)),
                    ),
                  ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Apunta el QR del asistente al centro',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_ultimoMensaje != null)
                  Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: _ultimoEsError
                            ? AppColors.danger
                            : AppColors.success,
                        width: 1.5,
                      ),
                      boxShadow: AppColors.shadowLifted,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _ultimoEsError
                              ? Symbols.error_rounded
                              : Symbols.check_circle_rounded,
                          color: _ultimoEsError
                              ? AppColors.danger
                              : AppColors.success,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _ultimoMensaje!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => context.pushReplacement(
                    RoutePaths.acreditarConfirmado(widget.eventoId),
                  ),
                  icon: const Icon(
                    Symbols.list_alt_rounded,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Ir a acreditación manual',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
