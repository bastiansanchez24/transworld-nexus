import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_tables.dart';
import '../models/lead.dart';
import '../offline/pending_photo_store.dart';
import '../offline/sync_queue_service.dart';
import '../supabase/supabase_client_provider.dart';
import 'storage_repository.dart';

/// CRUD de leads capturados (`public.leads`) + sync offline de inserts.
class LeadsRepository implements SyncExecutor {
  LeadsRepository(this._client, this._storage, this._fotosPendientes);

  final SupabaseClient _client;
  final StorageRepository _storage;
  final PendingPhotoStore _fotosPendientes;

  @override
  String get table => SupabaseTables.leads;

  static const _selectConPerfil =
      '*, perfiles!leads_perfil_id_fkey ( nombre_completo )';

  List<Lead> _mapRows(List<dynamic> rows) {
    return rows
        .map((row) => Lead.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<Lead>> listarPorEvento(String eventoId) async {
    final rows = await _client
        .from(SupabaseTables.leads)
        .select(_selectConPerfil)
        .eq('evento_id', eventoId)
        .order('created_at', ascending: false);
    return _mapRows(rows);
  }

  /// Leads capturados por un perfil concreto (más recientes primero).
  Future<List<Lead>> listarPorPerfil(String perfilId) async {
    final rows = await _client
        .from(SupabaseTables.leads)
        .select(_selectConPerfil)
        .eq('perfil_id', perfilId)
        .order('created_at', ascending: false);
    return _mapRows(rows);
  }

  Future<int> contarPorPerfil(String perfilId) async {
    final rows = await _client
        .from(SupabaseTables.leads)
        .select('id')
        .eq('perfil_id', perfilId);
    return rows.length;
  }

  Future<Lead> obtenerPorId(String id) async {
    final row = await _client
        .from(SupabaseTables.leads)
        .select(_selectConPerfil)
        .eq('id', id)
        .single();
    return Lead.fromMap(Map<String, dynamic>.from(row));
  }

  Future<Lead> crear(Lead lead) async {
    final userId = _client.auth.currentUser?.id;
    final fotos = await _subirFotosPendientes(lead.fotosUrls);
    final row = await _client
        .from(SupabaseTables.leads)
        .insert({
          ...lead.toInsertMap(),
          'fotos_urls': fotos.urls,
          'perfil_id': lead.perfilId ?? userId,
        })
        .select(_selectConPerfil)
        .single();
    await fotos.limpiarLocales();
    return Lead.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> actualizar(String id, Map<String, dynamic> changes) async {
    // Un lead capturado sin conexión puede seguir arrastrando su foto en
    // disco: si se edita ya con red, hay que subirla ahora en vez de mandar
    // el marcador `local_foto://` al servidor.
    final fotos = changes.containsKey('fotos_urls')
        ? await _subirFotosPendientes(_fotosDe(changes))
        : null;
    final data = fotos == null
        ? changes
        : {...changes, 'fotos_urls': fotos.urls};
    await _client.from(SupabaseTables.leads).update(data).eq('id', id);
    await fotos?.limpiarLocales();
  }

  /// Solo admin (política `cl_leads_delete` / `rpe_is_admin`).
  Future<void> eliminar(String id) async {
    await _client.from(SupabaseTables.leads).delete().eq('id', id);
  }

  @override
  Future<void> onInsert(Map<String, dynamic> payload) async {
    final data = Map<String, dynamic>.from(payload)..remove('id');
    final fotos = await _subirFotosPendientes(_fotosDe(data));
    data['fotos_urls'] = fotos.urls;
    await _client.from(SupabaseTables.leads).insert(data);
    await fotos.limpiarLocales();
  }

  @override
  Future<void> onUpdate(Map<String, dynamic> payload) async {
    final id = payload['id'] as String;
    final changes = Map<String, dynamic>.from(payload['changes'] as Map);
    final fotos = changes.containsKey('fotos_urls')
        ? await _subirFotosPendientes(_fotosDe(changes))
        : null;
    if (fotos != null) changes['fotos_urls'] = fotos.urls;
    await _client.from(SupabaseTables.leads).update(changes).eq('id', id);
    await fotos?.limpiarLocales();
  }

  List<String> _fotosDe(Map<String, dynamic> fila) {
    final valor = fila['fotos_urls'];
    if (valor is! List) return const [];
    return valor.map((e) => e.toString()).toList();
  }

  /// Sube a Storage las fotos que quedaron en disco por falta de red y
  /// devuelve la lista con las URLs públicas ya resueltas.
  ///
  /// Los archivos locales se borran recién cuando la fila llegó al servidor
  /// ([_FotosResueltas.limpiarLocales]): si el INSERT falla, la cola vuelve a
  /// intentarlo más tarde y la foto tiene que seguir ahí.
  Future<_FotosResueltas> _subirFotosPendientes(List<String> urls) async {
    if (!urls.any(esFotoLocal)) {
      return _FotosResueltas(urls, const [], _fotosPendientes);
    }

    final resueltas = <String>[];
    final consumidas = <String>[];
    for (final url in urls) {
      if (!esFotoLocal(url)) {
        resueltas.add(url);
        continue;
      }
      final bytes = await _fotosPendientes.leer(url);
      if (bytes == null) {
        // El archivo ya no está (datos limpiados, o el sistema recuperó
        // espacio). Se sincroniza el lead sin la foto en vez de dejar la
        // cola atascada: processPending no tiene tope de reintentos, así que
        // una excepción permanente acá bloquearía toda la sincronización.
        developer.log(
          'Foto pendiente perdida, el lead se sube sin ella: $url',
          name: 'LeadsRepository',
        );
        continue;
      }
      resueltas.add(await _storage.subirFotoLead(bytes, 'jpg'));
      consumidas.add(url);
    }
    return _FotosResueltas(resueltas, consumidas, _fotosPendientes);
  }
}

class _FotosResueltas {
  const _FotosResueltas(this.urls, this._consumidas, this._store);

  final List<String> urls;
  final List<String> _consumidas;
  final PendingPhotoStore _store;

  Future<void> limpiarLocales() async {
    for (final marcador in _consumidas) {
      await _store.borrar(marcador);
    }
  }
}

final leadsRepositoryProvider = Provider<LeadsRepository>((ref) {
  return LeadsRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(storageRepositoryProvider),
    ref.watch(pendingPhotoStoreProvider),
  );
});
