import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Tamaño del cuadro de enfoque respecto al ancho disponible (como en el legado).
const kQrScanWindowFraction = 0.7;

Rect computeQrScanWindow(BoxConstraints constraints) {
  final size = constraints.maxWidth * kQrScanWindowFraction;
  return Rect.fromCenter(
    center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
    width: size,
    height: size,
  );
}

/// Oscurece el preview y deja un recorte central transparente para el QR.
class QrScanDimOverlay extends StatelessWidget {
  const QrScanDimOverlay({super.key, required this.scanWindow});

  final Rect scanWindow;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _QrScanDimPainter(scanWindow: scanWindow),
      child: const SizedBox.expand(),
    );
  }
}

class _QrScanDimPainter extends CustomPainter {
  _QrScanDimPainter({required this.scanWindow});

  final Rect scanWindow;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(scanWindow, const Radius.circular(20)),
      );
    final cutout = Path.combine(PathOperation.difference, overlay, hole);
    canvas.drawPath(cutout, Paint()..color = const Color(0x80000000));
  }

  @override
  bool shouldRepaint(covariant _QrScanDimPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow;
  }
}

/// Esquinas verdes del marco de enfoque (misma idea que `acreditar-por-qr.tsx`).
class QrScanCornerFrame extends StatelessWidget {
  const QrScanCornerFrame({super.key, required this.scanWindow});

  final Rect scanWindow;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _QrScanCornerPainter(scanWindow: scanWindow),
      child: const SizedBox.expand(),
    );
  }
}

class _QrScanCornerPainter extends CustomPainter {
  _QrScanCornerPainter({required this.scanWindow});

  final Rect scanWindow;
  static const _cornerLen = 30.0;
  static const _stroke = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.success
      ..strokeWidth = _stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final r = scanWindow;
    // Top-left
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(_cornerLen, 0), paint);
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(0, _cornerLen), paint);
    // Top-right
    canvas.drawLine(r.topRight, r.topRight + const Offset(-_cornerLen, 0), paint);
    canvas.drawLine(r.topRight, r.topRight + const Offset(0, _cornerLen), paint);
    // Bottom-left
    canvas.drawLine(r.bottomLeft, r.bottomLeft + const Offset(_cornerLen, 0), paint);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + const Offset(0, -_cornerLen), paint);
    // Bottom-right
    canvas.drawLine(r.bottomRight, r.bottomRight + const Offset(-_cornerLen, 0), paint);
    canvas.drawLine(r.bottomRight, r.bottomRight + const Offset(0, -_cornerLen), paint);
  }

  @override
  bool shouldRepaint(covariant _QrScanCornerPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow;
  }
}
