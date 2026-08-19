import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/fijados_limits.dart';
import '../../core/constants/supabase_tables.dart';
import '../supabase/supabase_client_provider.dart';

/// Fijados personales sincronizados en Supabase (por usuario).
class FijadosRepository {
  FijadosRepository(this._client);

  final SupabaseClient _client;

  Future<List<String>> listarEventosFijadosOrdenados() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    final rows = await _client
        .from(SupabaseTables.usuariosEventosFijados)
        .select('evento_id')
        .eq('usuario_id', userId)
        .order('fijado_en', ascending: true);
    return rows.map((row) => row['evento_id'] as String).toList();
  }

  Future<List<String>> listarCampanasFijadasOrdenadas() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    final rows = await _client
        .from(SupabaseTables.usuariosEventosLeadsFijados)
        .select('evento_lead_id')
        .eq('usuario_id', userId)
        .order('fijado_en', ascending: true);
    return rows.map((row) => row['evento_lead_id'] as String).toList();
  }

  Future<Set<String>> listarEventosFijados() async {
    return (await listarEventosFijadosOrdenados()).toSet();
  }

  Future<Set<String>> listarCampanasFijadas() async {
    return (await listarCampanasFijadasOrdenadas()).toSet();
  }

  Future<void> fijarEvento(String eventoId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final actuales = await listarEventosFijados();
    if (actuales.contains(eventoId)) return;
    if (actuales.length >= kMaxFijadosPorTipo) {
      throw const FijadosLimitException('eventos');
    }

    await _client.from(SupabaseTables.usuariosEventosFijados).upsert({
      'usuario_id': userId,
      'evento_id': eventoId,
    });
  }

  Future<void> desfijarEvento(String eventoId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from(SupabaseTables.usuariosEventosFijados)
        .delete()
        .eq('usuario_id', userId)
        .eq('evento_id', eventoId);
  }

  Future<void> fijarCampana(String eventoLeadId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final actuales = await listarCampanasFijadas();
    if (actuales.contains(eventoLeadId)) return;
    if (actuales.length >= kMaxFijadosPorTipo) {
      throw const FijadosLimitException('actividades de captura');
    }

    await _client.from(SupabaseTables.usuariosEventosLeadsFijados).upsert({
      'usuario_id': userId,
      'evento_lead_id': eventoLeadId,
    });
  }

  Future<void> desfijarCampana(String eventoLeadId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from(SupabaseTables.usuariosEventosLeadsFijados)
        .delete()
        .eq('usuario_id', userId)
        .eq('evento_lead_id', eventoLeadId);
  }
}

final fijadosRepositoryProvider = Provider<FijadosRepository>((ref) {
  return FijadosRepository(ref.watch(supabaseClientProvider));
});
