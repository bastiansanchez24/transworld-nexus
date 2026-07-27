import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_tables.dart';
import '../models/lead.dart';
import '../offline/sync_queue_service.dart';
import '../supabase/supabase_client_provider.dart';

/// CRUD de leads capturados (`public.leads`) + sync offline de inserts.
class LeadsRepository implements SyncExecutor {
  LeadsRepository(this._client);

  final SupabaseClient _client;

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
    final row = await _client
        .from(SupabaseTables.leads)
        .insert({
          ...lead.toInsertMap(),
          'perfil_id': lead.perfilId ?? userId,
        })
        .select(_selectConPerfil)
        .single();
    return Lead.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> actualizar(String id, Map<String, dynamic> changes) async {
    await _client.from(SupabaseTables.leads).update(changes).eq('id', id);
  }

  /// Solo admin (política `cl_leads_delete` / `rpe_is_admin`).
  Future<void> eliminar(String id) async {
    await _client.from(SupabaseTables.leads).delete().eq('id', id);
  }

  @override
  Future<void> onInsert(Map<String, dynamic> payload) async {
    final data = Map<String, dynamic>.from(payload)..remove('id');
    await _client.from(SupabaseTables.leads).insert(data);
  }

  @override
  Future<void> onUpdate(Map<String, dynamic> payload) async {
    final id = payload['id'] as String;
    final changes = Map<String, dynamic>.from(payload['changes'] as Map);
    await _client.from(SupabaseTables.leads).update(changes).eq('id', id);
  }
}

final leadsRepositoryProvider = Provider<LeadsRepository>((ref) {
  return LeadsRepository(ref.watch(supabaseClientProvider));
});
