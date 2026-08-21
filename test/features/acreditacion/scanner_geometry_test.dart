import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:transworld_nexus/features/acreditacion/scanner/scanner_geometry.dart';

void main() {
  const preview = Size(390, 844);
  final window = scannerScanWindowFor(preview);

  BarcodeCapture captureWithCorners(List<Offset> corners) {
    return BarcodeCapture(
      size: preview,
      barcodes: [Barcode(rawValue: 'qr', corners: corners)],
    );
  }

  test('el cuadro visible conserva la geometría de producto', () {
    expect(window.center.dx, preview.width / 2);
    expect(window.center.dy, preview.height * 0.42);
    expect(window.width, preview.shortestSide * 0.68);
    expect(window.height, window.width);
  });

  test('acepta un QR completamente contenido', () {
    final inner = window.deflate(12);
    final result = captureFullyInsideScanWindow(
      captureWithCorners([
        inner.topLeft,
        inner.topRight,
        inner.bottomRight,
        inner.bottomLeft,
      ]),
      previewSize: preview,
      scanWindow: window,
    );

    expect(result.barcodes, hasLength(1));
  });

  test('rechaza un QR aunque solo una esquina quede fuera', () {
    final result = captureFullyInsideScanWindow(
      captureWithCorners([
        window.topLeft.translate(-1, 0),
        window.topRight,
        window.bottomRight,
        window.bottomLeft,
      ]),
      previewSize: preview,
      scanWindow: window,
    );

    expect(result.barcodes, isEmpty);
  });

  test('considera el recorte de BoxFit.cover', () {
    const camera = Size(1920, 1080);
    final centeredInCamera = <Offset>[
      const Offset(870, 350),
      const Offset(1050, 350),
      const Offset(1050, 550),
      const Offset(870, 550),
    ];
    final result = captureFullyInsideScanWindow(
      BarcodeCapture(
        size: camera,
        barcodes: [Barcode(rawValue: 'qr', corners: centeredInCamera)],
      ),
      previewSize: preview,
      scanWindow: window,
    );

    expect(result.barcodes, hasLength(1));
  });
}
