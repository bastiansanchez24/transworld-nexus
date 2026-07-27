import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_tables.dart';
import '../models/evento.dart';
import '../supabase/supabase_client_provider.dart';

/// CRUD de eventos.
///
/// Crear/editar exige admin u organizador (`rpe_can_create_content`).
/// Eliminar exige admin (`rpe_is_admin`). Operar eventos existentes está
/// abierto a usuarios internos; externos solo ven eventos autorizados.
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

  Future<int> contarCreadosPor(String perfilId) async {
    final rows = await _client
        .from(SupabaseTables.eventos)
        .select('id')
        .eq('creado_por', perfilId);
    return rows.length;
  }
}

final eventosRepositoryProvider = Provider<EventosRepository>((ref) {
  return EventosRepository(ref.watch(supabaseClientProvider));
});
