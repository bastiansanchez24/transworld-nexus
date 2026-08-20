import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'camera_service.dart';
import 'qr_scanner_service.dart';
import 'scanner_models.dart';

/// Controlador de presentación del escáner.
///
/// Maneja permisos, flash, fase de escaneo y resultado QR.
/// La UI solo observa este [ChangeNotifier]; la lógica de negocio
/// (acreditar / capturar lead) se engancha vía [onCodeDetected].
class ScannerController extends ChangeNotifier {
  ScannerController({
    CameraService? cameraService,
    QRScannerService? qrScannerService,
    this.onCodeDetected,
  }) : _camera = cameraService ?? CameraService(),
       _qr = qrScannerService ?? const QRScannerService();

  final CameraService _camera;
  final QRScannerService _qr;

  /// Callback de dominio: se invoca una vez por detección válida/inválida
  /// mientras [phase] == [ScannerPhase.idle] → pasa a processing.
  final Future<void> Function(QrScanDecode decode)? onCodeDetected;

  CameraService get camera => _camera;
  MobileScannerController get mobileController => _camera.controller;

  ScannerPermissionStatus _permission = ScannerPermissionStatus.checking;
  ScannerPermissionStatus get permission => _permission;

  ScannerPhase _phase = ScannerPhase.idle;
  ScannerPhase get phase => _phase;

  bool get isAnimatingCorners =>
      _permission == ScannerPermissionStatus.granted &&
      _phase == ScannerPhase.idle;

  bool _torchOn = false;
  bool get torchOn => _torchOn;

  bool _captureLeadMode = false;
  bool get captureLeadMode => _captureLeadMode;

  String? _feedbackMessage;
  String? get feedbackMessage => _feedbackMessage;

  bool _feedbackIsError = false;
  bool get feedbackIsError => _feedbackIsError;

  bool _disposed = false;

  Future<void> initialize() async {
    final status = await _camera.ensurePermission();
    if (_disposed) return;
    _permission = status;
    notifyListeners();
    // No arrancar la cámara aquí: mobile_scanner exige que el widget
    // [MobileScanner] esté montado. Ver [startAfterAttach].
  }

  /// Arranca el preview una vez que [MobileScanner] ya está en el árbol.
  /// Si se llama antes, falla con `controllerNotAttached` (más frecuente
  /// en release) y antes se interpretaba erróneamente como "sin permiso".
  Future<void> startAfterAttach() async {
    if (_disposed) return;
    if (_permission != ScannerPermissionStatus.granted) return;
    try {
      await _camera.start();
    } on MobileScannerException catch (e) {
      if (_disposed) return;
      if (e.errorCode == MobileScannerErrorCode.permissionDenied) {
        _permission = ScannerPermissionStatus.denied;
        notifyListeners();
      }
      // Otros errores (p. ej. already started) los reporta errorBuilder.
    } catch (_) {
      // El widget MobileScanner reporta el error vía errorBuilder.
    }
  }

  Future<void> retryPermission() async {
    _permission = ScannerPermissionStatus.checking;
    notifyListeners();
    await initialize();
    if (_permission == ScannerPermissionStatus.granted) {
      await startAfterAttach();
    }
  }

  Future<void> openSettings() => _camera.openSystemSettings();

  Future<void> toggleTorch() async {
    if (_permission != ScannerPermissionStatus.granted) return;
    _torchOn = !_torchOn;
    notifyListeners();
    await _camera.toggleTorch();
  }

  void toggleCaptureLeadMode() {
    if (_phase == ScannerPhase.processing) return;
    _captureLeadMode = !_captureLeadMode;
    notifyListeners();
  }

  void setCaptureLeadMode(bool value) {
    if (_captureLeadMode == value) return;
    _captureLeadMode = value;
    notifyListeners();
  }

  /// Entrada desde el widget de cámara. Ignora frames mientras no esté idle.
  Future<void> handleDetection(BarcodeCapture capture) async {
    if (_disposed) return;
    if (_phase != ScannerPhase.idle) return;
    if (_permission != ScannerPermissionStatus.granted) return;
    if (capture.barcodes.isEmpty) return;

    final decode = _qr.decode(capture);

    _phase = ScannerPhase.processing;
    notifyListeners();

    await HapticFeedback.mediumImpact();

    final handler = onCodeDetected;
    if (handler == null) {
      resumeScanning();
      return;
    }

    try {
      await handler(decode);
    } finally {
      // El handler puede haber llamado [showFeedback] o [resumeScanning].
      // Si sigue en processing (p. ej. canceló un diálogo), reanudar.
      if (!_disposed && _phase == ScannerPhase.processing) {
        resumeScanning(delay: const Duration(seconds: 2));
      }
    }
  }

  /// Muestra un mensaje breve y luego vuelve a [ScannerPhase.idle].
  void showFeedback(String message, {required bool isError}) {
    if (_disposed) return;
    _feedbackMessage = message;
    _feedbackIsError = isError;
    _phase = ScannerPhase.feedback;
    notifyListeners();

    Future.delayed(const Duration(seconds: 2), () {
      if (_disposed) return;
      _feedbackMessage = null;
      _phase = ScannerPhase.idle;
      notifyListeners();
    });
  }

  /// Mantiene el escáner sin detectar (p. ej. mientras hay un diálogo).
  ///
  /// Sale de [ScannerPhase.processing] para que el `finally` de
  /// [handleDetection] no reanude solo a los dos segundos.
  void holdScanning() {
    if (_disposed) return;
    _feedbackMessage = null;
    _phase = ScannerPhase.feedback;
    notifyListeners();
  }

  /// Reanuda detección (y animación de esquinas).
  void resumeScanning({Duration delay = Duration.zero}) {
    if (_disposed) return;
    _feedbackMessage = null;
    if (delay == Duration.zero) {
      _phase = ScannerPhase.idle;
      notifyListeners();
      return;
    }
    // Sale de [processing] de inmediato para que el finally de
    // [handleDetection] no vuelva a programar otro resume.
    _phase = ScannerPhase.feedback;
    notifyListeners();
    Future.delayed(delay, () {
      if (_disposed) return;
      _phase = ScannerPhase.idle;
      notifyListeners();
    });
  }

  /// Pausa el preview. En nativo no libera la sesión; en web sí (MediaStream).
  Future<void> pauseCamera() => _camera.pause();

  /// Libera la cámara (getUserMedia / sesión nativa). Llamar antes de pop.
  Future<void> stopCamera() => _camera.stop();

  Future<void> resumeCamera() async {
    if (_permission == ScannerPermissionStatus.granted) {
      await _camera.start();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_camera.dispose());
    super.dispose();
  }
}
