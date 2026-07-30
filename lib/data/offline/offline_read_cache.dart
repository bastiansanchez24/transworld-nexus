import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sync_queue_service.dart';

/// Última copia conocida de las listas por evento, para poder LEER sin
/// conexión.
///
/// [SyncQueueService] resuelve la escritura offline (lo capturado sin red se
/// sube después), pero no la lectura: sin esto, `listarPorEvento` falla al
/// quedarse sin señal y la lista —y el detalle de cada fila— quedan
/// inutilizables justo donde más se usan, en ferias y recintos con cobertura
/// intermitente.
class OfflineReadCache {
  const OfflineReadCache(this._prefs);

  final SharedPreferences _prefs;

  /// Una clave por tabla, para que leads y registrados no se pisen ni tengan
  /// que reescribir un blob común en cada refresco.
  static String _claveDe(String tabla) => 'offline_read_cache_v1_$tabla';

  /// Entrega lo del servidor y refresca la copia local. Si el servidor falla
  /// —típicamente por falta de red— devuelve la última copia guardada, y solo
  /// propaga el error cuando no hay ninguna.
  Future<List<T>> leerConRespaldo<T>({
    required String tabla,
    required String eventoId,
    required Future<List<T>> Function() desdeServidor,
    required Map<String, dynamic> Function(T) aFila,
    required T Function(Map<String, dynamic>) desdeFila,
  }) async {
    try {
      final frescos = await desdeServidor();
      await guardar(tabla, eventoId, frescos.map(aFila).toList());
      return frescos;
    } catch (error) {
      final respaldo = _respaldo(tabla, eventoId, desdeFila);
      if (respaldo == null) rethrow;
      developer.log(
        '$tabla/$eventoId servido desde la caché offline: $error',
        name: 'OfflineReadCache',
      );
      return respaldo;
    }
  }

  Future<void> guardar(
    String tabla,
    String eventoId,
    List<Map<String, dynamic>> filas,
  ) async {
    final todo = _leerTodo(tabla);
    todo[eventoId] = filas;
    await _prefs.setString(_claveDe(tabla), jsonEncode(todo));
  }

  List<T>? _respaldo<T>(
    String tabla,
    String eventoId,
    T Function(Map<String, dynamic>) desdeFila,
  ) {
    final filas = _leerTodo(tabla)[eventoId];
    if (filas is! List) return null;
    try {
      return filas
          .map((fila) => desdeFila(Map<String, dynamic>.from(fila as Map)))
          .toList();
    } catch (e) {
      developer.log(
        'Caché de $tabla ilegible, se descarta: $e',
        name: 'OfflineReadCache',
      );
      return null;
    }
  }

  Map<String, dynamic> _leerTodo(String tabla) {
    final raw = _prefs.getString(_claveDe(tabla));
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (e) {
      developer.log(
        'Caché de $tabla corrupta, se descarta: $e',
        name: 'OfflineReadCache',
      );
      return {};
    }
  }
}

final offlineReadCacheProvider = Provider<OfflineReadCache>((ref) {
  return OfflineReadCache(ref.watch(sharedPreferencesProvider));
});
