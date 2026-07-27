import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import 'scanner_models.dart';

/// Acceso a cámara y linterna. Sin lógica de UI ni de parseo QR.
class CameraService {
  CameraService({MobileScannerController? controller})
      : _controller = controller ??
            MobileScannerController(
              formats: [BarcodeFormat.qrCode],
              detectionSpeed: DetectionSpeed.normal,
              detectionTimeoutMs: 500,
              autoStart: false,
            );

  final MobileScannerController _controller;

  MobileScannerController get controller => _controller;

  bool _disposed = false;

  Future<ScannerPermissionStatus> ensurePermission() async {
    if (kIsWeb) {
      // El navegador gestiona el permiso al iniciar el stream.
      return ScannerPermissionStatus.granted;
    }

    var status = await Permission.camera.status;
    if (status.isGranted || status.isLimited) {
      return ScannerPermissionStatus.granted;
    }

    if (status.isDenied) {
      status = await Permission.camera.request();
      if (status.isGranted || status.isLimited) {
        return ScannerPermissionStatus.granted;
      }
    }

    if (status.isPermanentlyDenied || status.isDenied || status.isRestricted) {
      return ScannerPermissionStatus.denied;
    }

    return ScannerPermissionStatus.unavailable;
  }

  Future<void> start() async {
    if (_disposed) return;
    try {
      await _controller.start();
    } on Exception {
      // El widget MobileScanner reporta el error vía errorBuilder.
      rethrow;
    }
  }

  Future<void> stop() async {
    if (_disposed) return;
    try {
      await _controller.stop();
    } catch (_) {}
  }

  Future<void> toggleTorch() async {
    if (_disposed || kIsWeb) return;
    await _controller.toggleTorch();
  }

  bool get isTorchOn => _controller.value.torchState == TorchState.on;

  Future<void> openSystemSettings() => openAppSettings();

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _controller.stop();
    } catch (_) {}
    await _controller.dispose();
  }
}
