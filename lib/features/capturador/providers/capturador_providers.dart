import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../data/models/evento_lead.dart';
import '../../../data/models/lead.dart';
import '../../../data/offline/offline_read_cache.dart';
import '../../../data/offline/sync_queue_item.dart';
import '../../../data/offline/sync_queue_service.dart';
import '../../../data/repositories/eventos_leads_repository.dart';
import '../../../data/repositories/leads_repository.dart';

final eventosLeadsListProvider =
    FutureProvider.autoDispose<List<EventoLead>>((ref) {
  return ref.watch(eventosLeadsRepositoryProvider).listarTodos();
});

final eventoLeadByIdProvider =
    FutureProvider.autoDispose.family<EventoLead, String>((ref, id) {
  return ref.watch(eventosLeadsRepositoryProvider).obtenerPorId(id);
});

/// Combina los leads del servidor con lo que sigue pendiente en la cola
/// offline (inserts y updates). Si el servidor no responde se sirve la última
/// copia en caché, para que la lista y el detalle funcionen sin conexión.
final leadsPorEventoProvider =
    FutureProvider.autoDispose.family<List<Lead>, String>((ref, eventoId) async {
  final repo = ref.watch(leadsRepositoryProvider);

  final servidor = await ref.watch(offlineReadCacheProvider).leerConRespaldo(
        tabla: SupabaseTables.leads,
        eventoId: eventoId,
        desdeServidor: () => repo.listarPorEvento(eventoId),
        aFila: (lead) => lead.toCacheMap(),
        desdeFila: Lead.fromMap,
      );

  final colaDeLeads = ref
      .watch(syncQueueServiceProvider)
      .where((item) => item.table == SupabaseTables.leads);

  final inserts = colaDeLeads
      .where(
        (item) =>
            item.operation == SyncOperation.insert &&
            item.payload['evento_id'] == eventoId,
      )
      .map(
        (i) => Lead.fromMap({
          ...i.payload,
          'id': i.id,
        }).copyWith(pendienteDeSincronizar: true),
      )
      .toList();

  final cambiosPorId = <String, Map<String, dynamic>>{};
  for (final item in colaDeLeads) {
    if (item.operation != SyncOperation.update) continue;
    final id = item.payload['id'] as String;
    cambiosPorId[id] = {
      ...?cambiosPorId[id],
      ...Map<String, dynamic>.from(item.payload['changes'] as Map),
    };
  }

  final servidorConCambios = servidor.map((lead) {
    final cambios = cambiosPorId[lead.id];
    return cambios == null ? lead : lead.conCambiosPendientes(cambios);
  }).toList();

  return [...inserts, ...servidorConCambios];
});
