import 'package:flutter/widgets.dart';

/// Tamaño y proporción de la ventana de escritorio.
abstract final class DesktopWindowMetrics {
  /// Proporción de apertura: 4:3.
  static const aspect = 4 / 3;

  /// Mínimo a escala 100%. A 150% se reduce en lógicos para no ocupar
  /// casi toda la pantalla.
  static const minSize = Size(900, 600);

  /// Si no se puede leer el monitor (tests, error nativo).
  static const fallbackSize = Size(1024, 768);

  /// Deja aire respecto a la barra de tareas.
  static const workAreaFraction = 0.88;

  /// Ventana 4:3 que cabe en el área de trabajo (unidades lógicas).
  ///
  /// No se fuerza [minSize]: a escala 150% el escritorio lógico es más
  /// chico y 900 px ya no caben con holgura.
  static Size defaultSizeForWorkArea(Size workArea) {
    if (workArea.width <= 0 || workArea.height <= 0) return fallbackSize;

    final maxW = workArea.width * workAreaFraction;
    final maxH = workArea.height * workAreaFraction;
    final Size fitted;
    if (maxW / maxH > aspect) {
      fitted = Size(maxH * aspect, maxH);
    } else {
      fitted = Size(maxW, maxW / aspect);
    }

    return Size(
      fitted.width.clamp(1, workArea.width).roundToDouble(),
      fitted.height.clamp(1, workArea.height).roundToDouble(),
    );
  }

  /// Mínimo de resize en lógicos. A mayor [scaleFactor], más chico, para
  /// que no pise al tamaño inicial ni al área de trabajo.
  static Size minSizeFor({required Size workArea, double scaleFactor = 1}) {
    final scale = scaleFactor < 1 ? 1.0 : scaleFactor;
    final fitted = defaultSizeForWorkArea(workArea);
    final width = (minSize.width / scale).clamp(1, fitted.width);
    final height = (minSize.height / scale).clamp(1, fitted.height);
    return Size(width.roundToDouble(), height.roundToDouble());
  }
}
