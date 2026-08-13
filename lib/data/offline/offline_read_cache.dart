import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/connectivity_service.dart';
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
  OfflineReadCache(this._prefs, {this.ownerId});

  final SharedPreferences _prefs;
  final String? ownerId;

  /// Una clave por tabla, para que leads y registrados no se pisen ni tengan
  /// que reescribir un blob común en cada refresco.
  String? _claveDe(String tabla) {
    final owner = ownerId?.trim();
    if (owner == null || owner.isEmpty) return null;
    return 'offline_read_cache_v2_${owner}_$tabla';
  }

  /// Copia local sin tocar la red. Null si este evento nunca se cacheó.
  List<T>? leerLocal<T>({
    required String tabla,
    required String eventoId,
    required T Function(Map<String, dynamic>) desdeFila,
  }) {
    return _respaldo(tabla, eventoId, desdeFila);
  }

  /// Entrega lo del servidor y refresca la copia local. Si el servidor falla
  /// —típicamente por falta de red— devuelve la última copia guardada, y solo
  /// propaga el error cuando no hay ninguna.
  Future<List<T>> leerConRespaldo<T>({
    required String tabla,
    required String eventoId,
    required Future<List<T>> Function() desdeServidor,
    required Map<String, dynamic> Function(T) aFila,
    required T Function(Map<String, dynamic>) desdeFila,
    required bool isOnline,
  }) async {
    try {
      final frescos = await desdeServidor();
      await guardar(tabla, eventoId, frescos.map(aFila).toList());
      return frescos;
    } catch (error) {
      if (_esErrorDeAutorizacion(error)) {
        await eliminarEvento(tabla, eventoId);
        rethrow;
      }
      if (isOnline && !isNetworkTransportError(error)) {
        rethrow;
      }
      final respaldo = _respaldo(tabla, eventoId, desdeFila);
      if (respaldo == null) rethrow;
      developer.log(
        '$tabla/$eventoId servido desde la caché offline: $error',
        name: 'OfflineReadCache',
      );
      return respaldo;
    }
  }

  /// La caché v1 mezclaba cuentas. Sus filas no contienen evidencia suficiente
  /// del lector original, por lo que nunca se adoptan: se mueven en bruto a una
  /// cuarentena diagnóstica y se quitan de las claves activas.
  Future<int> quarantineLegacy() async {
    final owner = ownerId?.trim();
    if (owner == null || owner.isEmpty) return 0;
    final keys = _prefs
        .getKeys()
        .where((key) => key.startsWith('offline_read_cache_v1_'))
        .toList();
    for (final key in keys) {
      final raw = _prefs.getString(key);
      if (raw != null) {
        await _prefs.setString(
          'offline_read_cache_v2_quarantine_${key.substring('offline_read_cache_v1_'.length)}',
          raw,
        );
      }
      await _prefs.remove(key);
    }
    return keys.length;
  }

  Future<void> guardar(
    String tabla,
    String eventoId,
    List<Map<String, dynamic>> filas,
  ) async {
    final key = _claveDe(tabla);
    if (key == null) return;
    final todo = _leerTodo(tabla);
    todo[eventoId] = filas;
    await _prefs.setString(key, jsonEncode(todo));
  }

  /// Elimina inmediatamente una copia cuyo acceso fue rechazado por RLS.
  Future<void> eliminarEvento(String tabla, String eventoId) async {
    final key = _claveDe(tabla);
    if (key == null) return;
    final todo = _leerTodo(tabla);
    if (todo.remove(eventoId) == null) return;
    if (todo.isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, jsonEncode(todo));
    }
  }

  /// Conserva solo eventos que siguen autorizados. Debe llamarse únicamente
  /// después de resolver la lista desde servidor; un error de red nunca se
  /// interpreta como una revocación.
  Future<void> retenerEventos(
    String tabla,
    Set<String> eventosAutorizados,
  ) async {
    final key = _claveDe(tabla);
    if (key == null) return;
    final todo = _leerTodo(tabla);
    final cantidadOriginal = todo.length;
    todo.removeWhere((eventoId, _) => !eventosAutorizados.contains(eventoId));
    if (todo.length == cantidadOriginal) return;
    if (todo.isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, jsonEncode(todo));
    }
  }

  /// Purga filas cacheadas que pertenecen a otros perfiles. Se usa al cargar
  /// un rol con visibilidad privada de leads, incluido un downgrade de rol.
  Future<void> retenerFilasPropias(String tabla, String perfilId) async {
    final key = _claveDe(tabla);
    if (key == null) return;
    final todo = _leerTodo(tabla);
    var cambio = false;
    for (final entry in todo.entries.toList()) {
      final filas = entry.value;
      if (filas is! List) continue;
      final propias = filas.where((fila) {
        if (fila is! Map) return false;
        return fila['perfil_id']?.toString() == perfilId;
      }).toList();
      if (propias.length != filas.length) {
        todo[entry.key] = propias;
        cambio = true;
      }
    }
    if (cambio) await _prefs.setString(key, jsonEncode(todo));
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
    final key = _claveDe(tabla);
    if (key == null) return {};
    final raw = _prefs.getString(key);
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

  /// Los fallos de autorización/RLS nunca deben revivir datos locales. La
  /// comprobación es deliberadamente conservadora: solo cae a caché ante
  /// errores que el SDK o la plataforma identifican como red/transporte.
  bool _esErrorDeAutorizacion(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('401') ||
        message.contains('403') ||
        message.contains('row level security') ||
        message.contains('permission denied') ||
        message.contains('not authenticated') ||
        message.contains('jwt');
  }
}

final offlineReadCacheProvider = Provider<OfflineReadCache>((ref) {
  final cache = OfflineReadCache(
    ref.watch(sharedPreferencesProvider),
    ownerId: ref.watch(syncQueueActiveOwnerIdProvider),
  );
  unawaited(cache.quarantineLegacy());
  return cache;
});
