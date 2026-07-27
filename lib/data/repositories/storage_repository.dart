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

  Future<String> subirImagenEvento(Uint8List bytes, String extension) async {
    final fileName = 'eventos/${_uuid.v4()}.$extension';
    await _client.storage.from(Env.bucketImagenes).uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from(Env.bucketImagenes).getPublicUrl(fileName);
  }

  /// Foto adjunta a un lead capturado (`leads.fotos_urls`).
  Future<String> subirFotoLead(Uint8List bytes, String extension) async {
    final ext = extension.toLowerCase().replaceAll('.', '');
    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' || 'heif' => 'image/heic',
      _ => 'image/jpeg',
    };
    final fileName = 'leads/${_uuid.v4()}.$ext';
    await _client.storage.from(Env.bucketImagenes).uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: contentType,
          ),
        );
    return _client.storage.from(Env.bucketImagenes).getPublicUrl(fileName);
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
