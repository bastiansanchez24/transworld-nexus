import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_tables.dart';
import '../models/lead_comentario.dart';
import '../supabase/supabase_client_provider.dart';

class LeadComentariosRepository {
  LeadComentariosRepository(this._client);

  final SupabaseClient _client;

  Future<List<LeadComentario>> listar(String leadId) async {
    final rows = await _client
        .from(SupabaseTables.leadComentarios)
        .select()
        .eq('lead_id', leadId)
        .order('created_at', ascending: true);
    return [
      for (final row in rows)
        LeadComentario.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }

  /// Comentarios de varios leads en una sola consulta, para la exportación.
  ///
  /// Pedirlos lead por lead haría una petición por fila del Excel.
  Future<List<LeadComentario>> listarPorLeads(List<String> leadIds) async {
    final ids = leadIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const [];
    final rows = await _client
        .from(SupabaseTables.leadComentarios)
        .select()
        .inFilter('lead_id', ids)
        .order('created_at', ascending: true);
    return [
      for (final row in rows)
        LeadComentario.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<LeadComentario> crear({
    required String leadId,
    required String cuerpo,
  }) async {
    final texto = cuerpo.trim();
    if (texto.isEmpty) {
      throw ArgumentError('El comentario no puede estar vacío.');
    }
    if (texto.length > kLeadComentarioMaxCaracteres) {
      throw ArgumentError(
        'El comentario no puede superar los '
        '$kLeadComentarioMaxCaracteres caracteres.',
      );
    }

    final row = await _client
        .from(SupabaseTables.leadComentarios)
        .insert({'lead_id': leadId, 'cuerpo': texto})
        .select()
        .single();
    return LeadComentario.fromMap(Map<String, dynamic>.from(row));
  }

  Future<LeadComentario> editar({
    required String comentarioId,
    required String cuerpo,
  }) async {
    final texto = cuerpo.trim();
    if (texto.isEmpty) {
      throw ArgumentError('El comentario no puede estar vacío.');
    }
    if (texto.length > kLeadComentarioMaxCaracteres) {
      throw ArgumentError(
        'El comentario no puede superar los '
        '$kLeadComentarioMaxCaracteres caracteres.',
      );
    }
    final row = await _client
        .from(SupabaseTables.leadComentarios)
        .update({'cuerpo': texto})
        .eq('id', comentarioId)
        .select()
        .single();
    return LeadComentario.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> borrar(String comentarioId) async {
    await _client
        .from(SupabaseTables.leadComentarios)
        .delete()
        .eq('id', comentarioId);
  }
}

final leadComentariosRepositoryProvider = Provider<LeadComentariosRepository>((
  ref,
) {
  return LeadComentariosRepository(ref.watch(supabaseClientProvider));
});
