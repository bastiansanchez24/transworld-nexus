import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_tables.dart';
import '../models/notificacion.dart';
import '../supabase/supabase_client_provider.dart';

class NotificacionesRepository {
  NotificacionesRepository(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  Future<List<NotificacionInbox>> listar({int limite = 100}) async {
    final userId = _userId;
    if (userId == null) return const [];

    final notificaciones = await _client
        .from(SupabaseTables.notificaciones)
        .select()
        .order('created_at', ascending: false)
        .limit(limite);

    final leidasRows = await _client
        .from(SupabaseTables.notificacionesLeidas)
        .select('notificacion_id')
        .eq('usuario_id', userId);

    final ocultasRows = await _client
        .from(SupabaseTables.notificacionesOcultas)
        .select('notificacion_id')
        .eq('usuario_id', userId);

    final leidas = leidasRows
        .map((r) => r['notificacion_id'] as String)
        .toSet();

    final ocultas = ocultasRows
        .map((r) => r['notificacion_id'] as String)
        .toSet();

    return notificaciones
        .where((row) => !ocultas.contains(row['id'] as String))
        .map(
          (row) => NotificacionInbox.fromMap(
            row,
            leida: leidas.contains(row['id'] as String),
          ),
        )
        .toList();
  }

  Future<int> contarNoLeidas() async {
    final lista = await listar();
    return lista.where((n) => !n.leida).length;
  }

  Future<void> marcarLeida(String notificacionId) async {
    final userId = _userId;
    if (userId == null) return;

    await _client.from(SupabaseTables.notificacionesLeidas).upsert({
      'usuario_id': userId,
      'notificacion_id': notificacionId,
      'leida_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'usuario_id,notificacion_id');
  }

  Future<void> marcarTodasLeidas(List<String> notificacionIds) async {
    final userId = _userId;
    if (userId == null || notificacionIds.isEmpty) return;

    final ahora = DateTime.now().toUtc().toIso8601String();
    await _client
        .from(SupabaseTables.notificacionesLeidas)
        .upsert(
          notificacionIds
              .map(
                (id) => {
                  'usuario_id': userId,
                  'notificacion_id': id,
                  'leida_at': ahora,
                },
              )
              .toList(),
          onConflict: 'usuario_id,notificacion_id',
        );
  }

  /// Oculta notificaciones del inbox del usuario actual sin borrarlas globalmente.
  Future<void> ocultarNotificaciones(List<String> notificacionIds) async {
    final userId = _userId;
    if (userId == null || notificacionIds.isEmpty) return;

    final ahora = DateTime.now().toUtc().toIso8601String();
    await _client
        .from(SupabaseTables.notificacionesOcultas)
        .upsert(
          notificacionIds
              .map(
                (id) => {
                  'usuario_id': userId,
                  'notificacion_id': id,
                  'oculta_at': ahora,
                },
              )
              .toList(),
          onConflict: 'usuario_id,notificacion_id',
        );
  }

  /// Oculta todas las notificaciones existentes para el usuario autenticado.
  Future<void> ocultarTodasNotificaciones() async {
    await _client.rpc(SupabaseRpc.ocultarTodasNotificaciones);
  }

  Future<void> guardarDeviceToken({
    required String token,
    required String plataforma,
  }) async {
    final userId = _userId;
    if (userId == null) return;

    await _client.from(SupabaseTables.deviceTokens).upsert({
      'usuario_id': userId,
      'token': token,
      'plataforma': plataforma,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token');
  }

  Future<void> eliminarDeviceToken(String token) async {
    await _client.from(SupabaseTables.deviceTokens).delete().eq('token', token);
  }

  Future<void> eliminarTokensDelUsuario() async {
    final userId = _userId;
    if (userId == null) return;

    await _client
        .from(SupabaseTables.deviceTokens)
        .delete()
        .eq('usuario_id', userId);
  }
}

final notificacionesRepositoryProvider = Provider<NotificacionesRepository>(
  (ref) => NotificacionesRepository(ref.watch(supabaseClientProvider)),
);
