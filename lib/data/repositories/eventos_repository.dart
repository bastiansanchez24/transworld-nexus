import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_tables.dart';
import '../models/evento.dart';
import '../supabase/supabase_client_provider.dart';

/// CRUD de eventos.
///
/// La creación/edición/eliminación de eventos solo la permite la base de
/// datos a usuarios con `rol = 'admin'` (políticas `rpe_eventos_insert` /
/// `_update` / `_delete` en supabase/schema.sql). Esto corrige el hallazgo
/// de la Sección 8.2/17.6: en el proyecto legado, las políticas de `eventos`
/// eran `USING (true) WITH CHECK (true)` para cualquier autenticado, y la
/// única barrera era ocultar el botón en la UI.
class EventosRepository {
  EventosRepository(this._client);

  final SupabaseClient _client;

  Future<List<Evento>> listarTodos() async {
    final rows = await _client
        .from(SupabaseTables.eventos)
        .select()
        .order('fecha', ascending: false);
    return rows.map(Evento.fromMap).toList();
  }

  Future<Evento> obtenerPorId(String id) async {
    final row = await _client
        .from(SupabaseTables.eventos)
        .select()
        .eq('id', id)
        .single();
    return Evento.fromMap(row);
  }

  Future<Evento> crear(Evento evento) async {
    final userId = _client.auth.currentUser?.id;
    final row = await _client
        .from(SupabaseTables.eventos)
        .insert({...evento.toInsertMap(), 'creado_por': userId})
        .select()
        .single();
    return Evento.fromMap(row);
  }

  Future<void> actualizar(String id, Map<String, dynamic> changes) async {
    await _client.from(SupabaseTables.eventos).update(changes).eq('id', id);
  }

  Future<void> eliminar(String id) async {
    await _client.from(SupabaseTables.eventos).delete().eq('id', id);
  }
}

final eventosRepositoryProvider = Provider<EventosRepository>((ref) {
  return EventosRepository(ref.watch(supabaseClientProvider));
});
