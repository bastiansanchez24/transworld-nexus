// Implementación vacía para web: no hay sistema de archivos donde guardar las
// portadas, y allí tampoco existe el modo offline (ver `OfflinePolicy`), así
// que las imágenes se siguen sirviendo desde la red.

import 'dart:typed_data';

bool get almacenamientoDisponible => false;

Future<String> rutaDe(String nombre) async => nombre;

Future<bool> existe(String ruta) async => false;

Future<void> escribir(String ruta, Uint8List bytes) async {}

Future<void> borrarTodo() async {}

Future<int> borrarSalvo(Set<String> nombres) async => 0;
