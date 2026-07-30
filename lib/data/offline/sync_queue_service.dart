import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'sync_queue_item.dart';

/// Ejecuta un ítem de la cola contra el backend real. Cada feature que
/// necesite soporte offline (por ahora, registrados) implementa uno de
/// estos y lo registra en [SyncCoordinator] — así el motor de sincronización
/// no depende directamente de Supabase ni de un dominio en particular.
abstract class SyncExecutor {
  String get table;

  Future<void> onInsert(Map<String, dynamic> payload);

  Future<void> onUpdate(Map<String, dynamic> payload);
}

const _prefsKey = 'sync_queue_v1';
const _uuid = Uuid();

/// Prefijo de los ids temporales que [SyncQueueService.enqueueInsert] asigna
/// a las filas que todavía no existen en el servidor.
const syncLocalIdPrefix = 'local_';

/// true si [id] es uno de esos ids temporales, es decir, si la fila vive solo
/// en la cola local.
///
/// Es la pregunta correcta antes de un UPDATE, un DELETE o de generar un QR:
/// distinta de `pendienteDeSincronizar`, que también vale `true` para una fila
/// ya sincronizada que solo tiene una edición esperando en la cola.
bool esIdSoloLocal(String id) => id.startsWith(syncLocalIdPrefix);

/// Única cola de sincronización offline de toda la app.
///
/// Corrige el bug crítico documentado en `documentacion_zips_registro_pro.md`
/// (Secciones 3.8, 4.8 y 17.3): en el proyecto legado, la app móvil tenía DOS
/// colas offline desconectadas — una en `lib/offlineManager.ts` (clave
/// `capturador_leads_cola_offline`, jamás escrita) y otra usada por las
/// pantallas directamente (clave `registro_pro_cola_offline`, jamás leída
/// por el motor de sincronización). El resultado era que nada capturado sin
/// conexión llegaba nunca a Supabase.
///
/// Acá solo existe ESTA clase. Ninguna pantalla debe leer/escribir
/// `SharedPreferences` directamente para temas de sincronización: todo pasa
/// por [enqueueInsert] / [enqueueUpdate] / [processPending].
class SyncQueueService extends StateNotifier<List<SyncQueueItem>> {
  SyncQueueService(this._prefs) : super(const []) {
    _restore();
  }

  final SharedPreferences _prefs;

  void _restore() {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      state = decoded
          .map((e) => SyncQueueItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log('No se pudo restaurar la cola offline: $e',
          name: 'SyncQueueService');
    }
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(state.map((e) => e.toJson()).toList());
    await _prefs.setString(_prefsKey, encoded);
  }

  List<SyncQueueItem> pendingFor(String table) => state
      .where((i) => i.table == table && i.status != SyncStatus.synced)
      .toList();

  int get pendingCount =>
      state.where((i) => i.status != SyncStatus.synced).length;

  /// Encola un INSERT y devuelve el id local temporal generado, para que la
  /// UI pueda mostrar el registro de inmediato (con `pendienteDeSincronizar
  /// = true`) sin esperar al servidor.
  Future<String> enqueueInsert({
    required String table,
    required Map<String, dynamic> payload,
  }) async {
    final id = '$syncLocalIdPrefix${_uuid.v4()}';
    final now = DateTime.now();
    final item = SyncQueueItem(
      id: id,
      operation: SyncOperation.insert,
      table: table,
      payload: {...payload, 'id': id},
      createdAt: now,
      updatedAt: now,
    );
    state = [...state, item];
    await _persist();
    return id;
  }

  /// Encola un UPDATE. Si el `entityId` corresponde a un INSERT todavía
  /// pendiente (empieza con `local_` y sigue en la cola), el cambio se
  /// fusiona directamente en ese ítem en vez de crear una operación nueva
  /// — evita intentar "actualizar" una fila que el servidor todavía no
  /// conoce.
  Future<void> enqueueUpdate({
    required String table,
    required String entityId,
    required Map<String, dynamic> changes,
  }) async {
    final pendingInsertIndex = state.indexWhere(
      (i) =>
          i.id == entityId &&
          i.operation == SyncOperation.insert &&
          i.status != SyncStatus.synced,
    );

    if (pendingInsertIndex != -1) {
      final current = state[pendingInsertIndex];
      final merged = {...current.payload, ...changes};
      state = [
        for (final item in state)
          if (item.id == current.id) current.copyWith(payload: merged) else item,
      ];
      await _persist();
      return;
    }

    final now = DateTime.now();
    final item = SyncQueueItem(
      id: _uuid.v4(),
      operation: SyncOperation.update,
      table: table,
      payload: {'id': entityId, 'changes': changes},
      createdAt: now,
      updatedAt: now,
    );
    state = [...state, item];
    await _persist();
  }

  /// Procesa toda la cola pendiente usando los [executors] disponibles
  /// (uno por tabla). Devuelve cuántos ítems se sincronizaron con éxito.
  Future<int> processPending(Map<String, SyncExecutor> executors) async {
    var syncedCount = 0;
    final pending = state
        .where((i) => i.status == SyncStatus.pending || i.status == SyncStatus.failed)
        .toList();

    for (final item in pending) {
      final executor = executors[item.table];
      if (executor == null) continue;

      _updateItem(item.copyWith(status: SyncStatus.syncing));

      try {
        if (item.operation == SyncOperation.insert) {
          await executor.onInsert(item.payload);
        } else {
          await executor.onUpdate(item.payload);
        }
        state = state.where((i) => i.id != item.id).toList();
        syncedCount++;
        await _persist();
      } catch (e) {
        _updateItem(item.copyWith(
          status: SyncStatus.failed,
          retries: item.retries + 1,
          lastError: e.toString(),
        ));
        await _persist();
      }
    }

    return syncedCount;
  }

  void _updateItem(SyncQueueItem updated) {
    state = [
      for (final item in state)
        if (item.id == updated.id) updated else item,
    ];
  }

  Future<void> clearSynced() async {
    state = state.where((i) => i.status != SyncStatus.synced).toList();
    await _persist();
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider debe sobreescribirse en main.dart con '
    'ProviderScope(overrides: [...]) usando la instancia ya inicializada.',
  );
});

final syncQueueServiceProvider =
    StateNotifierProvider<SyncQueueService, List<SyncQueueItem>>((ref) {
  return SyncQueueService(ref.watch(sharedPreferencesProvider));
});

final pendingSyncCountProvider = Provider<int>((ref) {
  final items = ref.watch(syncQueueServiceProvider);
  return items.where((i) => i.status != SyncStatus.synced).length;
});
