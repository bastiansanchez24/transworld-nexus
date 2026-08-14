import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
// ignore: implementation_imports — force-stop nativo no está en la API pública.
import 'package:mobile_scanner/src/method_channel/mobile_scanner_method_channel.dart';
import 'package:permission_handler/permission_handler.dart';

import 'scanner_models.dart';
import 'web_camera_tracks.dart';

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
  bool _platformForceStopped = false;
  Future<void>? _operation;

  /// Serializa start/stop/pause para evitar carreras en release (CameraX).
  Future<T> _runExclusive<T>(Future<T> Function() action) async {
    final previous = _operation;
    final gate = Completer<void>();
    _operation = gate.future;
    if (previous != null) {
      try {
        await previous;
      } catch (_) {}
    }
    try {
      return await action();
    } finally {
      gate.complete();
      if (identical(_operation, gate.future)) {
        _operation = null;
      }
    }
  }

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

  /// En release, mobile_scanner solo hace force-stop en debug. Si quedó una
  /// sesión nativa viva (p. ej. tras un dispose incompleto), CameraX falla
  /// con CAMERA_ERROR → "An unexpected error occurred".
  Future<void> _ensurePlatformIdle() async {
    if (_platformForceStopped || kIsWeb) return;
    _platformForceStopped = true;
    if (MobileScannerPlatform.instance
        case final MethodChannelMobileScanner implementation) {
      try {
        await implementation.stop(force: true);
      } catch (_) {}
    }
  }

  Future<void> start() async {
    if (_disposed) return;
    await _runExclusive(() async {
      if (_disposed) return;
      if (_controller.value.isRunning || _controller.value.isStarting) {
        return;
      }

      await _ensurePlatformIdle();
      await _startOnce();

      // Platform errors (CAMERA_ERROR, etc.) no se relanzan: quedan en
      // controller.value.error y el widget muestra "unexpected error".
      final error = _controller.value.error;
      if (_disposed || error == null) return;
      if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
        return;
      }
      if (error.errorCode == MobileScannerErrorCode.controllerAlreadyInitialized ||
          error.errorCode == MobileScannerErrorCode.controllerInitializing) {
        return;
      }

      _platformForceStopped = false;
      await _ensurePlatformIdle();
      if (_disposed) return;
      if (_controller.value.isRunning || _controller.value.isStarting) return;
      await _startOnce();
    });
  }

  Future<void> _startOnce() async {
    try {
      await _controller.start();
    } on MobileScannerException catch (e) {
      if (e.errorCode == MobileScannerErrorCode.controllerAlreadyInitialized ||
          e.errorCode == MobileScannerErrorCode.controllerInitializing) {
        return;
      }
      rethrow;
    }
  }

  /// En nativo mantiene la sesión (evita CAMERA_ERROR al reanudar).
  /// En web equivale a [stop]: `pause()` solo pausa el `<video>` y el
  /// indicador de cámara del navegador permanece encendido.
  Future<void> pause() async {
    if (kIsWeb) {
      await stop();
      return;
    }
    if (_disposed) return;
    await _runExclusive(() async {
      if (_disposed) return;
      try {
        await _controller.pause();
      } catch (_) {}
    });
  }

  Future<void> stop() async {
    if (_disposed) return;
    await _runExclusive(() async {
      if (_disposed) return;
      await _releaseSession();
    });
  }

  /// [MobileScannerController.stop] no hace nada si ya está en pause
  /// (`isRunning == false`). En web eso deja el MediaStream vivo.
  Future<void> _releaseSession() async {
    try {
      await _controller.stop();
    } catch (_) {}
    if (!kIsWeb) return;
    try {
      await MobileScannerPlatform.instance.stop();
    } catch (_) {}
    stopOrphanWebCameraTracks();
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
    await _runExclusive(() async {
      await _releaseSession();
      await _controller.dispose();
    });
  }
}
