import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const double kScannerScanWindowFraction = 0.68;

/// Única fuente de verdad para el cuadro visible y el área de detección.
Rect scannerScanWindowFor(
  Size size, {
  double fraction = kScannerScanWindowFraction,
}) {
  final side = size.shortestSide * fraction;
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height * 0.42),
    width: side,
    height: side,
  );
}

/// Conserva únicamente códigos cuyas cuatro esquinas están dentro del cuadro.
///
/// `mobile_scanner` ya recibe [scanWindow], pero en iOS la región de interés de
/// Vision puede entregar un QR que solo intersecta ese rectángulo. Esta segunda
/// barrera aplica el criterio de producto de forma idéntica en cada plataforma.
BarcodeCapture captureFullyInsideScanWindow(
  BarcodeCapture capture, {
  required Size previewSize,
  required Rect scanWindow,
  DeviceOrientation? orientation,
}) {
  var cameraSize = capture.size;
  if (orientation == DeviceOrientation.landscapeLeft ||
      orientation == DeviceOrientation.landscapeRight) {
    cameraSize = cameraSize.flipped;
  }

  if (cameraSize.isEmpty || previewSize.isEmpty) {
    return const BarcodeCapture();
  }

  final scale = math.max(
    previewSize.width / cameraSize.width,
    previewSize.height / cameraSize.height,
  );
  final horizontalCrop = (cameraSize.width * scale - previewSize.width) / 2;
  final verticalCrop = (cameraSize.height * scale - previewSize.height) / 2;

  bool isInside(Barcode barcode) {
    if (barcode.corners.length < 4) return false;
    return barcode.corners.every((corner) {
      final point = Offset(
        corner.dx * scale - horizontalCrop,
        corner.dy * scale - verticalCrop,
      );
      return scanWindow.contains(point);
    });
  }

  final accepted = capture.barcodes.where(isInside).toList(growable: false);
  if (accepted.isEmpty) return const BarcodeCapture();

  return BarcodeCapture(
    barcodes: accepted,
    image: capture.image,
    raw: capture.raw,
    size: capture.size,
  );
}
