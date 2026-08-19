import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/connectivity_service.dart';
import 'sync_queue_service.dart';

/// `eventoId` reservado para las tablas que no se particionan por evento
/// (perfil, catálogo de eventos, usuarios, fijados).
///
/// No puede colisionar con un id real: los eventos son UUID.
const String cacheAmbitoGlobal = '__global__';

/// Tiempo máximo que la UI espera al servidor antes de servir la copia local.
///
/// Sin esto, un wifi cautivo —el escenario exacto de feria— deja la pantalla
/// en `loading` indefinidamente aunque el disco tenga una copia buena: la
/// petición no falla, simplemente nunca responde. `connectivity_plus` informa
/// que hay interfaz, así que tampoco hay una señal de "offline" que corte.
const Duration esperaMaximaServidorPorDefecto = Duration(seconds: 5);

const String _prefijoV3 = 'offline_read_cache_v3';
const String _prefijoV2 = 'offline_read_cache_v2';
const String _prefijoV1 = 'offline_read_cache_v1_';
const String _sufijoIndice = '__idx';

/// Última copia conocida de las listas por evento, para poder LEER sin
/// conexión.
///
/// [SyncQueueService] resuelve la escritura offline (lo capturado sin red se
/// sube después), pero no la lectura: sin esto, `listarPorEvento` falla al
/// quedarse sin señal y la lista —y el detalle de cada fila— quedan
/// inutilizables justo donde más se usan, en ferias y recintos con cobertura
/// intermitente.
///
/// El almacenamiento es **una clave por `(tabla, evento)`** más un índice de
/// eventos por tabla. El formato v2 guardaba un único blob por tabla y lo
/// re-serializaba entero en cada escritura de un evento; con el snapshot
/// completo (~10 eventos × cientos de filas) eso reescribía megabytes de JSON
/// por cada evento guardado.
class OfflineReadCache {
  OfflineReadCache(this._prefs, {this.ownerId});

  final SharedPreferences _prefs;
  final String? ownerId;

  /// Tablas cuya migración desde v2 ya se comprobó en esta instancia.
  final Set<String> _tablasMigradas = <String>{};

  String? get _owner {
    final owner = ownerId?.trim();
    if (owner == null || owner.isEmpty) return null;
    return owner;
  }

  /// Clave de datos de un evento concreto. `:` separa tabla de evento porque
  /// ningún nombre de tabla lo contiene; así dos pares distintos no pueden
  /// producir la misma clave.
  String? _claveDatos(String tabla, String eventoId) {
    final owner = _owner;
    if (owner == null) return null;
    return '${_prefijoV3}_${owner}_$tabla:$eventoId';
  }

  /// Índice de eventos guardados de una tabla. Sin él no se puede recorrer la
  /// tabla para purgar (`retenerEventos`, `retenerFilasPropias`).
  String? _claveIndice(String tabla) {
    final owner = _owner;
    if (owner == null) return null;
    return '${_prefijoV3}_${owner}_$tabla$_sufijoIndice';
  }

  Set<String> _indice(String tabla) {
    final key = _claveIndice(tabla);
    if (key == null) return {};
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as List<dynamic>).map((e) => '$e').toSet();
    } catch (e) {
      developer.log(
        'Índice de $tabla corrupto, se descarta: $e',
        name: 'OfflineReadCache',
      );
      return {};
    }
  }

  Future<void> _guardarIndice(String tabla, Set<String> eventos) async {
    final key = _claveIndice(tabla);
    if (key == null) return;
    if (eventos.isEmpty) {
      await _prefs.remove(key);
      return;
    }
    await _prefs.setString(key, jsonEncode(eventos.toList()));
  }

  /// Copia local sin tocar la red. Null si este evento nunca se cacheó.
  List<T>? leerLocal<T>({
    required String tabla,
    required String eventoId,
    required T Function(Map<String, dynamic>) desdeFila,
  }) {
    return _respaldo(tabla, eventoId, desdeFila);
  }

  /// Variante de [leerLocal] para tablas que no se particionan por evento.
  List<T>? leerGlobal<T>({
    required String tabla,
    required T Function(Map<String, dynamic>) desdeFila,
  }) {
    return _respaldo(tabla, cacheAmbitoGlobal, desdeFila);
  }

  /// Entrega lo del servidor y refresca la copia local. Si el servidor falla
  /// —típicamente por falta de red— devuelve la última copia guardada, y solo
  /// propaga el error cuando no hay ninguna.
  ///
  /// La llamada al servidor está acotada por [esperaMaximaServidor]: una
  /// petición que nunca responde se trata como fallo de transporte y cae a la
  /// copia local en vez de dejar la UI colgada.
  Future<List<T>> leerConRespaldo<T>({
    required String tabla,
    required String eventoId,
    required Future<List<T>> Function() desdeServidor,
    required Map<String, dynamic> Function(T) aFila,
    required T Function(Map<String, dynamic>) desdeFila,
    required bool isOnline,
    Duration esperaMaximaServidor = esperaMaximaServidorPorDefecto,
  }) async {
    try {
      final frescos = await desdeServidor().timeout(esperaMaximaServidor);
      await guardar(tabla, eventoId, frescos.map(aFila).toList());
      return frescos;
    } catch (error) {
      if (_esRevocacionConfirmada(error) ||
          _esCredencialInvalidaConServidor(error, isOnline: isOnline)) {
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

  /// Variante de [leerConRespaldo] para tablas sin partición por evento.
  Future<List<T>> leerConRespaldoGlobal<T>({
    required String tabla,
    required Future<List<T>> Function() desdeServidor,
    required Map<String, dynamic> Function(T) aFila,
    required T Function(Map<String, dynamic>) desdeFila,
    required bool isOnline,
    Duration esperaMaximaServidor = esperaMaximaServidorPorDefecto,
  }) {
    return leerConRespaldo<T>(
      tabla: tabla,
      eventoId: cacheAmbitoGlobal,
      desdeServidor: desdeServidor,
      aFila: aFila,
      desdeFila: desdeFila,
      isOnline: isOnline,
      esperaMaximaServidor: esperaMaximaServidor,
    );
  }

  /// La caché v1 mezclaba cuentas. Sus filas no contienen evidencia suficiente
  /// del lector original, por lo que nunca se adoptan: se mueven en bruto a una
  /// cuarentena diagnóstica y se quitan de las claves activas.
  Future<int> quarantineLegacy() async {
    if (_owner == null) return 0;
    final keys = _prefs
        .getKeys()
        .where((key) => key.startsWith(_prefijoV1))
        .toList();
    for (final key in keys) {
      final raw = _prefs.getString(key);
      if (raw != null) {
        await _prefs.setString(
          '${_prefijoV3}_quarantine_${key.substring(_prefijoV1.length)}',
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
    _migrarV2SiHaceFalta(tabla);
    final key = _claveDatos(tabla, eventoId);
    if (key == null) return;
    await _prefs.setString(key, jsonEncode(filas));
    final indice = _indice(tabla);
    if (indice.add(eventoId)) await _guardarIndice(tabla, indice);
  }

  /// Variante de [guardar] para tablas sin partición por evento.
  Future<void> guardarGlobal(String tabla, List<Map<String, dynamic>> filas) {
    return guardar(tabla, cacheAmbitoGlobal, filas);
  }

  /// Elimina inmediatamente una copia cuyo acceso fue rechazado por RLS.
  Future<void> eliminarEvento(String tabla, String eventoId) async {
    _migrarV2SiHaceFalta(tabla);
    final key = _claveDatos(tabla, eventoId);
    if (key == null) return;
    await _prefs.remove(key);
    final indice = _indice(tabla);
    if (indice.remove(eventoId)) await _guardarIndice(tabla, indice);
  }

  /// Conserva solo eventos que siguen autorizados. Debe llamarse únicamente
  /// después de resolver la lista desde servidor; un error de red nunca se
  /// interpreta como una revocación.
  ///
  /// El ámbito global no se toca: no representa un evento y no está sujeto a
  /// la lista de autorizaciones.
  Future<void> retenerEventos(
    String tabla,
    Set<String> eventosAutorizados,
  ) async {
    _migrarV2SiHaceFalta(tabla);
    final indice = _indice(tabla);
    final sobrantes = indice
        .where(
          (eventoId) =>
              eventoId != cacheAmbitoGlobal &&
              !eventosAutorizados.contains(eventoId),
        )
        .toList();
    if (sobrantes.isEmpty) return;
    for (final eventoId in sobrantes) {
      final key = _claveDatos(tabla, eventoId);
      if (key != null) await _prefs.remove(key);
      indice.remove(eventoId);
    }
    await _guardarIndice(tabla, indice);
  }

  /// Purga filas cacheadas que pertenecen a otros perfiles. Se usa al cargar
  /// un rol con visibilidad privada de leads, incluido un downgrade de rol.
  Future<void> retenerFilasPropias(String tabla, String perfilId) async {
    _migrarV2SiHaceFalta(tabla);
    for (final eventoId in _indice(tabla)) {
      final key = _claveDatos(tabla, eventoId);
      if (key == null) continue;
      final filas = _filasCrudas(key);
      if (filas == null) continue;
      final propias = filas.where((fila) {
        if (fila is! Map) return false;
        return fila['perfil_id']?.toString() == perfilId;
      }).toList();
      if (propias.length != filas.length) {
        await _prefs.setString(key, jsonEncode(propias));
      }
    }
  }

  List<T>? _respaldo<T>(
    String tabla,
    String eventoId,
    T Function(Map<String, dynamic>) desdeFila,
  ) {
    _migrarV2SiHaceFalta(tabla);
    final key = _claveDatos(tabla, eventoId);
    if (key == null) return null;
    final filas = _filasCrudas(key);
    if (filas == null) return null;
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

  List<dynamic>? _filasCrudas(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (e) {
      developer.log(
        'Caché corrupta en $key, se descarta: $e',
        name: 'OfflineReadCache',
      );
      return null;
    }
  }

  /// Reparte el blob v2 de [tabla] en una clave por evento.
  ///
  /// Es perezosa y síncrona a efectos de lectura: `SharedPreferences` publica
  /// el valor en su mapa en memoria al invocar `setString`, así que la lectura
  /// inmediatamente posterior ya ve las claves nuevas aunque la escritura en
  /// disco siga en vuelo. Migrar en el constructor obligaría a que todo lector
  /// esperara un future que hoy nadie espera.
  void _migrarV2SiHaceFalta(String tabla) {
    if (!_tablasMigradas.add(tabla)) return;
    final owner = _owner;
    if (owner == null) {
      // Sin sesión no hay namespace: no marcarla como migrada, para reintentar
      // cuando el owner exista.
      _tablasMigradas.remove(tabla);
      return;
    }

    final claveV2 = '${_prefijoV2}_${owner}_$tabla';
    final raw = _prefs.getString(claveV2);
    if (raw == null || raw.isEmpty) return;

    try {
      final todo = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final indice = _indice(tabla);
      for (final entry in todo.entries) {
        if (entry.value is! List) continue;
        final key = _claveDatos(tabla, entry.key);
        if (key == null) continue;
        unawaited(_prefs.setString(key, jsonEncode(entry.value)));
        indice.add(entry.key);
      }
      unawaited(_guardarIndice(tabla, indice));
    } catch (e) {
      developer.log(
        'Caché v2 de $tabla ilegible, se descarta: $e',
        name: 'OfflineReadCache',
      );
    }
    unawaited(_prefs.remove(claveV2));
  }

  /// Denegación que solo puede venir de una respuesta del servidor. Purgar es
  /// obligatorio aunque el dispositivo figure offline: si el acceso fue
  /// revocado, una desconexión posterior no puede revivir el evento.
  bool _esRevocacionConfirmada(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('401') ||
        message.contains('403') ||
        message.contains('row level security') ||
        message.contains('permission denied');
  }

  /// Fallo de credencial que el SDK también levanta en local, sin que el
  /// servidor haya dicho nada: un token vencido mientras el teléfono estuvo
  /// días sin abrirse produce exactamente esto. Sin evidencia de respuesta del
  /// servidor no es una revocación, y borrar ahí la caché destruiría los datos
  /// de la feria justo cuando no hay red para recuperarlos.
  bool _esCredencialInvalidaConServidor(
    Object error, {
    required bool isOnline,
  }) {
    if (!isOnline || isNetworkTransportError(error)) return false;
    final message = error.toString().toLowerCase();
    return message.contains('jwt') || message.contains('not authenticated');
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
