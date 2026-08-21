import 'dart:io';

import 'package:flutter/material.dart';

/// Pinta un archivo local. Solo existe en plataformas con `dart:io`.
Widget imagenDeDisco({
  required String ruta,
  required BoxFit fit,
  required Alignment alignment,
  required FilterQuality filterQuality,
  required bool expandir,
  int? cacheWidth,
  required Widget Function() alFallar,
  Widget Function()? mientrasCarga,
}) {
  return Image.file(
    File(ruta),
    fit: fit,
    alignment: alignment,
    gaplessPlayback: true,
    filterQuality: filterQuality,
    width: expandir ? double.infinity : null,
    height: expandir ? double.infinity : null,
    cacheWidth: cacheWidth,
    // Decodificar una foto grande toma algún frame: hasta que llega el
    // primero se muestra el mismo indicador que en la ruta de red.
    frameBuilder: mientrasCarga == null
        ? null
        : (context, child, frame, sincrona) =>
              sincrona || frame != null ? child : mientrasCarga(),
    // El archivo puede haberse borrado (limpieza de datos, recuperación de
    // espacio): la red sigue siendo el respaldo.
    errorBuilder: (_, _, _) => alFallar(),
  );
}
