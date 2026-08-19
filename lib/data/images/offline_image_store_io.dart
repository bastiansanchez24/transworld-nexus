// Implementación de disco del almacén de imágenes offline, para las
// plataformas con `dart:io`.
//
// Se importa condicionalmente desde `offline_image_store.dart`; en web se usa
// `offline_image_store_stub.dart`, porque `dart:io` ni siquiera compila allí.

import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

const _carpeta = 'imagenes_offline';

bool get almacenamientoDisponible => true;

Future<Directory> _directorio() async {
  // Documentos y no caché: el sistema puede purgar la caché justo antes de la
  // feria, que es cuando ya no hay red para volver a bajar las portadas.
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory('${base.path}${Platform.pathSeparator}$_carpeta');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

Future<String> rutaDe(String nombre) async {
  final dir = await _directorio();
  return '${dir.path}${Platform.pathSeparator}$nombre';
}

Future<bool> existe(String ruta) => File(ruta).exists();

Future<void> escribir(String ruta, Uint8List bytes) async {
  await File(ruta).writeAsBytes(bytes, flush: true);
}

Future<void> borrarTodo() async {
  try {
    final dir = await _directorio();
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (e) {
    developer.log(
      'No se pudieron borrar las imágenes offline: $e',
      name: 'OfflineImageStore',
    );
  }
}
