import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/env.dart';
import '../supabase/supabase_client_provider.dart';

class StorageRepository {
  StorageRepository(this._client);

  final SupabaseClient _client;
  final _uuid = const Uuid();

  /// Imagen de portada de un evento. Siempre llega ya comprimida a JPEG por
  /// `comprimirParaSubida`, de ahí que el content-type sea fijo.
  Future<String> subirImagenEvento(Uint8List bytes, String extension) {
    return _subir('eventos/${_uuid.v4()}.$extension', bytes, 'image/jpeg');
  }

  /// Foto de perfil. El path fijo evita archivos huérfanos, mientras que el
  /// query versionado invalida la caché y se persiste junto con la URL.
  Future<String> subirFotoPerfil(Uint8List bytes, String userId) async {
    final url = await _subir('perfiles/$userId.jpg', bytes, 'image/jpeg');
    return agregarVersionCacheImagen(
      url,
      DateTime.now().microsecondsSinceEpoch,
    );
  }

  /// Foto adjunta a un lead capturado (`leads.fotos_urls`).
  Future<String> subirFotoLead(Uint8List bytes, String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' || 'heif' => 'image/heic',
      _ => 'image/jpeg',
    };
    return _subir('leads/${_uuid.v4()}.$ext', bytes, contentType);
  }

  Future<String> _subir(
    String fileName,
    Uint8List bytes,
    String contentType,
  ) async {
    final bucket = _client.storage.from(Env.bucketImagenes);
    try {
      await bucket.uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(upsert: true, contentType: contentType),
      );
    } on StorageException catch (e) {
      throw Exception(_mensajeDeError(e));
    }
    return bucket.getPublicUrl(fileName);
  }

  /// Sin esto la UI muestra el volcado crudo de `StorageException`, que no le
  /// dice a nadie qué hay que arreglar.
  String _mensajeDeError(StorageException e) {
    if (e.statusCode == '403' || e.statusCode == '401') {
      // Falta la política de INSERT sobre storage.objects para este bucket
      // (sección 6 de supabase/schema.sql). No es algo que la app pueda
      // resolver: hay que crearla en la base.
      return 'Storage rechazó la subida (${e.statusCode}): el bucket '
          '"${Env.bucketImagenes}" no tiene política de escritura para este '
          'usuario. Hay que crearla en storage.objects.';
    }
    if (e.statusCode == '404') {
      return 'El bucket "${Env.bucketImagenes}" no existe en este proyecto '
          'de Supabase.';
    }
    if (e.statusCode == '413') {
      return 'La imagen supera el tamaño máximo permitido por Storage.';
    }
    return 'No se pudo subir la imagen: ${e.message}';
  }

  String urlPlantillaRegistro() {
    return _client.storage
        .from(Env.bucketPlantillas)
        .getPublicUrl('Plantilla_Registro.xlsx');
  }
}

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  return StorageRepository(ref.watch(supabaseClientProvider));
});

String agregarVersionCacheImagen(String url, int version) {
  final separador = url.contains('?') ? '&' : '?';
  return '$url${separador}v=$version';
}
