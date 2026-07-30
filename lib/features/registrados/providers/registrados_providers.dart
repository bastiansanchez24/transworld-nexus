import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../data/models/registrado.dart';
import '../../../data/offline/offline_read_cache.dart';
import '../../../data/offline/sync_queue_item.dart';
import '../../../data/offline/sync_queue_service.dart';
import '../../../data/repositories/registrados_repository.dart';

/// Combina los registrados que ya confirmó el servidor con los que siguen
/// pendientes en la cola offline unificada (ver
/// data/offline/sync_queue_service.dart), para que la UI los muestre de
/// inmediato con una insignia de "pendiente de sincronizar" — sin esto, el
/// bug de cola huérfana del proyecto legado (Sección 3.8/17.3) habría sido
/// invisible para el usuario hasta perder los datos.
final registradosPorEventoProvider = FutureProvider.autoDispose
    .family<List<Registrado>, String>((ref, eventoId) async {
  final repo = ref.watch(registradosRepositoryProvider);

  final servidor = await ref.watch(offlineReadCacheProvider).leerConRespaldo(
        tabla: SupabaseTables.registrados,
        eventoId: eventoId,
        desdeServidor: () => repo.listarPorEvento(eventoId),
        aFila: (registrado) => registrado.toCacheMap(),
        desdeFila: Registrado.fromMap,
      );

  final colaCompleta = ref.watch(syncQueueServiceProvider);
  final colaDeEsteEvento = colaCompleta.where(
    (item) => item.table == SupabaseTables.registrados,
  );

  final inserts = colaDeEsteEvento
      .where((i) =>
          i.operation == SyncOperation.insert &&
          i.payload['evento_id'] == eventoId)
      .map((i) => Registrado.fromMap(i.payload).copyWith(pendienteDeSincronizar: true))
      .toList();

  final updatesPorId = <String, Map<String, dynamic>>{};
  for (final item in colaDeEsteEvento) {
    if (item.operation != SyncOperation.update) continue;
    final id = item.payload['id'] as String;
    final changes = Map<String, dynamic>.from(item.payload['changes'] as Map);
    updatesPorId[id] = {...updatesPorId[id] ?? {}, ...changes};
  }

  final servidorConCambios = servidor.map((r) {
    final changes = updatesPorId[r.id];
    return changes == null ? r : r.conCambiosPendientes(changes);
  }).toList();

  return [...inserts, ...servidorConCambios];
});

/// true si ese correo ya está registrado en el evento, considerando también
/// los registros que aún no confirma el servidor (evita duplicados visibles
/// para el usuario incluso mientras está offline).
bool existeEmailPendienteODuplicado(
  List<SyncQueueItem> cola,
  String eventoId,
  String email,
) {
  final emailNormalizado = email.trim().toLowerCase();
  return cola.any((item) =>
      item.table == SupabaseTables.registrados &&
      item.operation == SyncOperation.insert &&
      item.payload['evento_id'] == eventoId &&
      (item.payload['email'] as String?)?.trim().toLowerCase() == emailNormalizado);
}
