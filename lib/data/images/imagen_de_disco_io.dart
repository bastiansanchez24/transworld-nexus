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
    // El archivo puede haberse borrado (limpieza de datos, recuperación de
    // espacio): la red sigue siendo el respaldo.
    errorBuilder: (_, _, _) => alFallar(),
  );
}
