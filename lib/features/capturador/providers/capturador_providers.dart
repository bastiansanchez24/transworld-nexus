import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../data/models/evento_lead.dart';
import '../../../data/models/lead.dart';
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

/// Combina leads del servidor con inserts pendientes en la cola offline.
final leadsPorEventoProvider =
    FutureProvider.autoDispose.family<List<Lead>, String>((ref, eventoId) async {
  final repo = ref.watch(leadsRepositoryProvider);
  final servidor = await repo.listarPorEvento(eventoId);

  final colaCompleta = ref.watch(syncQueueServiceProvider);
  final inserts = colaCompleta
      .where(
        (item) =>
            item.table == SupabaseTables.leads &&
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

  return [...inserts, ...servidor];
});

final leadByIdProvider =
    FutureProvider.autoDispose.family<Lead, String>((ref, id) {
  return ref.watch(leadsRepositoryProvider).obtenerPorId(id);
});
