import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_tables.dart';
import '../models/evento_lead.dart';
import '../supabase/supabase_client_provider.dart';

/// Escapa comodines de ILIKE para forzar coincidencia literal.
String _escapeIlikeLiteral(String raw) {
  return raw
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}

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
        .map((row) => EventoLead.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Evento de leads interno de un evento de registro. El índice único parcial
  /// de `evento_origen_id` garantiza que haya como máximo uno.
  Future<EventoLead?> buscarPorEventoOrigen(String eventoOrigenId) async {
    if (eventoOrigenId.isEmpty) return null;

    final row = await _client
        .from(SupabaseTables.eventosLeads)
        .select()
        .eq('evento_origen_id', eventoOrigenId)
        .maybeSingle();

    if (row == null) return null;
    return EventoLead.fromMap(Map<String, dynamic>.from(row));
  }

  /// Busca por nombre exacto (case-insensitive), sin comodines ILIKE. Solo para
  /// los eventos de leads previos al vínculo por id, que no tienen origen.
  /// Si hay homónimos legacy, devuelve el más antiguo (`created_at`).
  Future<EventoLead?> buscarPorNombre(String nombre) async {
    final nombreNormalizado = nombre.trim();
    if (nombreNormalizado.isEmpty) return null;

    final rows = await _client
        .from(SupabaseTables.eventosLeads)
        .select()
        .ilike('nombre', _escapeIlikeLiteral(nombreNormalizado));

    final lower = nombreNormalizado.toLowerCase();
    final matches = rows
        .map((row) => EventoLead.fromMap(Map<String, dynamic>.from(row as Map)))
        .where((c) => c.nombre.trim().toLowerCase() == lower)
        .toList();

    if (matches.isEmpty) return null;
    matches.sort((a, b) {
      final ac = a.createdAt;
      final bc = b.createdAt;
      if (ac != null && bc != null) return ac.compareTo(bc);
      if (ac != null) return -1;
      if (bc != null) return 1;
      return a.id.compareTo(b.id);
    });
    return matches.first;
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
        .insert({...evento.toInsertMap(), 'perfil_id': userId})
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
