import 'package:flutter/material.dart';

/// En web no hay sistema de archivos: siempre se cae a la red.
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
  return alFallar();
}
