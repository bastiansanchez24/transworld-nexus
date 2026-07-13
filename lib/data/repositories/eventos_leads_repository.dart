import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_tables.dart';
import '../models/evento_lead.dart';
import '../supabase/supabase_client_provider.dart';

/// CRUD de eventos del capturador (`public.eventos_leads`).
class EventosLeadsRepository {
  EventosLeadsRepository(this._client);

  final SupabaseClient _client;

  Future<List<EventoLead>> listarTodos() async {
    final rows = await _client
        .from(SupabaseTables.eventosLeads)
        .select()
        .order('fecha', ascending: false);
    return rows
        .map(
          (row) => EventoLead.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<EventoLead> obtenerPorId(String id) async {
    final row = await _client
        .from(SupabaseTables.eventosLeads)
        .select()
        .eq('id', id)
        .single();
    return EventoLead.fromMap(Map<String, dynamic>.from(row));
  }

  Future<EventoLead> crear(EventoLead evento) async {
    final userId = _client.auth.currentUser?.id;
    final row = await _client
        .from(SupabaseTables.eventosLeads)
        .insert({
          ...evento.toInsertMap(),
          'perfil_id': userId,
        })
        .select()
        .single();
    return EventoLead.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> actualizar(String id, Map<String, dynamic> changes) async {
    await _client
        .from(SupabaseTables.eventosLeads)
        .update(changes)
        .eq('id', id);
  }

  Future<void> eliminar(String id) async {
    await _client.from(SupabaseTables.eventosLeads).delete().eq('id', id);
  }
}

final eventosLeadsRepositoryProvider = Provider<EventosLeadsRepository>((ref) {
  return EventosLeadsRepository(ref.watch(supabaseClientProvider));
});
