// Implementación vacía para web: no hay sistema de archivos donde dejar una
// foto esperando a que vuelva la red, así que las pantallas deben avisar y
// guardar el lead sin foto.

import 'dart:typed_data';

bool get almacenamientoDisponible => false;

Future<String> guardarFoto(Uint8List bytes) {
  throw UnsupportedError(
    'No se pueden diferir fotos en web: no hay almacenamiento local.',
  );
}

Future<Uint8List?> leerFoto(String ruta) async => null;

Future<void> borrarFoto(String ruta) async {}
