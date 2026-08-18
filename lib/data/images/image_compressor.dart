import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Lado largo máximo (px) de cualquier imagen que suba la app.
const int kLadoMaximoSubida = 1024;

/// Calidad JPEG de salida. Agresiva a propósito: las fotos se capturan en
/// ferias con datos móviles y solo se miran en pantalla.
const int kCalidadJpegSubida = 45;

/// Redimensiona a [ladoMaximo] px el lado largo y reencoda a JPEG [calidad].
///
/// Se hace en Dart en vez de delegar en `image_picker`, porque sus flags
/// `maxWidth` / `imageQuality` solo los honran Android e iOS: en Windows,
/// Linux, macOS y web se ignoran en silencio y hoy se sube el archivo
/// original completo. Acá el resultado es el mismo en las seis plataformas.
///
/// Con [recorteProporcion] la imagen además se recorta centrada a esa
/// proporción (ancho/alto) antes de escalar: `1` deja un cuadrado. Si es
/// `null` se conserva la proporción original.
///
/// Lanza [FormatException] si los bytes no son una imagen que se pueda
/// decodificar.
Future<Uint8List> comprimirParaSubida(
  Uint8List original, {
  int ladoMaximo = kLadoMaximoSubida,
  int calidad = kCalidadJpegSubida,
  double? recorteProporcion,
}) {
  return compute(
    _comprimirSync,
    _ArgsCompresion(original, ladoMaximo, calidad, recorteProporcion),
  );
}

@immutable
class _ArgsCompresion {
  const _ArgsCompresion(
    this.bytes,
    this.ladoMaximo,
    this.calidad,
    this.recorteProporcion,
  );

  final Uint8List bytes;
  final int ladoMaximo;
  final int calidad;
  final double? recorteProporcion;
}

/// Top-level porque [compute] solo acepta funciones que puedan viajar a otro
/// isolate. En web corre en línea, que a 1024 px es barato.
Uint8List _comprimirSync(_ArgsCompresion args) {
  // `decodeImage` a veces devuelve null y a veces revienta con un error de
  // rango (p. ej. un archivo truncado): las dos formas de "esto no es una
  // imagen" se unifican acá para que el llamador tenga un solo caso.
  img.Image? decodificada;
  try {
    decodificada = img.decodeImage(args.bytes);
  } catch (_) {
    decodificada = null;
  }
  if (decodificada == null) {
    throw const FormatException('No se pudo leer la imagen seleccionada.');
  }

  // Las fotos de cámara traen la rotación en el EXIF; al reencodar a JPEG ese
  // metadato se pierde, así que hay que aplicarlo antes o salen giradas.
  var imagen = img.bakeOrientation(decodificada);

  // Recorte centrado, antes de escalar: así el archivo que se sube ya tiene
  // la proporción con la que se va a mostrar y no hay recortes distintos
  // según el widget que lo pinte.
  final proporcion = args.recorteProporcion;
  if (proporcion != null && proporcion > 0) {
    final ancho = imagen.width / imagen.height > proporcion
        ? (imagen.height * proporcion).round()
        : imagen.width;
    final alto = imagen.width / imagen.height > proporcion
        ? imagen.height
        : (imagen.width / proporcion).round();
    if (ancho != imagen.width || alto != imagen.height) {
      imagen = img.copyCrop(
        imagen,
        x: (imagen.width - ancho) ~/ 2,
        y: (imagen.height - alto) ~/ 2,
        width: ancho,
        height: alto,
      );
    }
  }

  final ladoLargo =
      imagen.width > imagen.height ? imagen.width : imagen.height;
  if (ladoLargo > args.ladoMaximo) {
    final esApaisada = imagen.width >= imagen.height;
    imagen = img.copyResize(
      imagen,
      width: esApaisada ? args.ladoMaximo : null,
      height: esApaisada ? null : args.ladoMaximo,
      interpolation: img.Interpolation.average,
    );
  }

  return img.encodeJpg(imagen, quality: args.calidad);
}
