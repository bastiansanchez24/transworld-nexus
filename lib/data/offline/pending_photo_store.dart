import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pending_photo_store_stub.dart'
    if (dart.library.io) 'pending_photo_store_io.dart' as plataforma;

/// Prefijo que marca una foto que todavía vive en el disco del dispositivo y
/// aún no se subió a Supabase Storage.
///
/// El marcador viaja dentro de `fotos_urls` como si fuera una URL más. Así
/// atraviesa `Lead.fromMap`, `toInsertMap`, `toCacheMap` y la rehidratación
/// de inserts pendientes sin que ninguno de esos puntos tenga que saber que
/// existe: el único lugar que debe resolverlo es el borde con Supabase
/// (ver `LeadsRepository`).
const String fotoLocalPrefix = 'local_foto://';

bool esFotoLocal(String url) => url.startsWith(fotoLocalPrefix);

/// Guarda en disco las fotos capturadas sin conexión, hasta que la cola de
/// sincronización pueda subirlas.
///
/// No se guardan dentro de la cola porque [SyncQueueService] serializa su
/// estado a JSON en `SharedPreferences`: meter ahí los bytes de una foto,
/// aunque fuera en base64, no es viable.
class PendingPhotoStore {
  const PendingPhotoStore();

  /// `false` en web, donde no hay sistema de archivos. Allí una foto
  /// capturada sin conexión no se puede diferir y hay que avisarlo.
  bool get disponible => plataforma.almacenamientoDisponible;

  /// Escribe [bytes] y devuelve el marcador `local_foto://<ruta>`.
  Future<String> guardar(Uint8List bytes) async {
    return '$fotoLocalPrefix${await plataforma.guardarFoto(bytes)}';
  }

  /// Devuelve `null` si el archivo ya no está (el usuario limpió datos o el
  /// sistema recuperó espacio). Quien llame debe poder seguir sin la foto.
  Future<Uint8List?> leer(String marcador) {
    if (!esFotoLocal(marcador)) return Future.value();
    return plataforma.leerFoto(marcador.substring(fotoLocalPrefix.length));
  }

  Future<void> borrar(String marcador) {
    if (!esFotoLocal(marcador)) return Future.value();
    return plataforma.borrarFoto(marcador.substring(fotoLocalPrefix.length));
  }
}

final pendingPhotoStoreProvider = Provider<PendingPhotoStore>((ref) {
  return const PendingPhotoStore();
});

/// Bytes de una foto que todavía está en disco, cacheados por marcador.
///
/// Riverpod evita releer el archivo en cada rebuild: sin esto, una lista de
/// leads con fotos pendientes golpearía el disco en cada frame de scroll.
final fotoPendienteBytesProvider =
    FutureProvider.family<Uint8List?, String>((ref, marcador) {
  return ref.watch(pendingPhotoStoreProvider).leer(marcador);
});
