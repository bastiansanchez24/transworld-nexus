import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'login_theme.dart';

/// Cabecera hero del flujo de autenticación.
///
/// En vez de una fotografía, dibuja un visual abstracto del dominio
/// (credencial, trama tipo QR, anillos) con [CustomPaint] — sin assets
/// externos, así escala nítido en cualquier densidad y plataforma.
class LoginHeader extends StatelessWidget {
  const LoginHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.borderRadius = const BorderRadius.vertical(
      bottom: Radius.circular(LoginTheme.heroRadius),
    ),
  });

  final String title;
  final String subtitle;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _EventHeroPainter()),
          // Overlay oscuro muy sutil para asegurar legibilidad del texto.
          Container(color: Colors.black.withValues(alpha: 0.10)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Composición abstracta: fondo con degradado suave de la marca, anillos,
/// una "credencial" inclinada y una trama de puntos que evoca un QR.
class _EventHeroPainter extends CustomPainter {
  const _EventHeroPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Fondo: degradado suave (no saturado) entre los azules de marca.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ).createShader(rect),
    );

    final soft = Paint()..color = Colors.white.withValues(alpha: 0.06);
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // Círculo grande difuso arriba a la derecha + anillo concéntrico.
    final c = Offset(size.width * 0.86, size.height * 0.18);
    canvas.drawCircle(c, size.shortestSide * 0.34, soft);
    canvas.drawCircle(c, size.shortestSide * 0.46, line);

    // Anillo pequeño a la izquierda.
    canvas.drawCircle(
      Offset(size.width * 0.10, size.height * 0.62),
      size.shortestSide * 0.12,
      line,
    );

    // "Credencial" inclinada (gafete con orificio de lanyard).
    canvas.save();
    canvas.translate(size.width * 0.68, size.height * 0.66);
    canvas.rotate(-0.22);
    final badge = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.shortestSide * 0.42,
        height: size.shortestSide * 0.56,
      ),
      const Radius.circular(14),
    );
    canvas.drawRRect(badge, Paint()..color = Colors.white.withValues(alpha: 0.10));
    canvas.drawRRect(badge, line);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -badge.height * 0.34),
          width: badge.width * 0.32,
          height: 7,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
    canvas.restore();

    // Trama de puntos redondeados (evoca un código QR) abajo a la izquierda.
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.16);
    const cell = 16.0;
    const dotSize = 6.0;
    // Patrón fijo determinista para que no "baile" entre repintados.
    const pattern = [
      [1, 1, 1, 0, 1, 0, 1],
      [1, 0, 0, 1, 0, 1, 0],
      [1, 1, 0, 1, 1, 0, 1],
      [0, 0, 1, 0, 1, 1, 0],
      [1, 0, 1, 1, 0, 1, 1],
    ];
    final origin = Offset(size.width * 0.06, size.height * 0.74);
    for (var fila = 0; fila < pattern.length; fila++) {
      for (var col = 0; col < pattern[fila].length; col++) {
        if (pattern[fila][col] == 0) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              origin.dx + col * cell,
              origin.dy + fila * cell,
              dotSize,
              dotSize,
            ),
            const Radius.circular(2),
          ),
          dot,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EventHeroPainter oldDelegate) => false;
}
