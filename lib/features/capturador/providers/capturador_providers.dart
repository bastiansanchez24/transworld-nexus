import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../data/models/evento_lead.dart';
import '../../../data/models/lead.dart';
import '../../../data/offline/offline_read_cache.dart';
import '../../../data/offline/sync_queue_item.dart';
import '../../../data/offline/sync_queue_service.dart';
import '../../../data/repositories/eventos_leads_repository.dart';
import '../../../data/repositories/leads_repository.dart';
import '../../auth/providers/auth_providers.dart';

final eventosLeadsListProvider = FutureProvider.autoDispose<List<EventoLead>>((
  ref,
) {
  return ref.watch(eventosLeadsRepositoryProvider).listarTodos();
});

final eventoLeadByIdProvider = FutureProvider.autoDispose
    .family<EventoLead, String>((ref, id) {
      return ref.watch(eventosLeadsRepositoryProvider).obtenerPorId(id);
    });

/// Evento de leads interno de un evento de registro, o `null` si todavía no se
/// ha creado. El menú de Evento lo usa para ofrecer crearlo o abrirlo.
final eventoLeadInternoProvider = FutureProvider.autoDispose
    .family<EventoLead?, String>((ref, eventoOrigenId) {
      return ref
          .watch(eventosLeadsRepositoryProvider)
          .buscarPorEventoOrigen(eventoOrigenId);
    });

Iterable<SyncQueueItem> leadQueueItemsForOverlay(
  Iterable<SyncQueueItem> items,
) {
  return items.where(
    (item) =>
        item.table == SupabaseTables.leads &&
        item.status != SyncStatus.conflict &&
        item.status != SyncStatus.synced,
  );
}

List<Lead> fusionarLeadsConCola({
  required List<Lead> servidor,
  required Iterable<SyncQueueItem> colaDeLeads,
  required String eventoId,
}) {
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
}

class LeadsResumen {
  const LeadsResumen({required this.total, required this.empresas});

  final int total;
  final int empresas;

  factory LeadsResumen.fromMap(Map<String, dynamic> map) {
    return LeadsResumen(
      total: (map['total'] as num?)?.toInt() ?? 0,
      empresas: (map['empresas'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toCacheMap() => {'total': total, 'empresas': empresas};
}

String leadsCacheTabla(bool canViewAllLeads) =>
    '${SupabaseTables.leads}__${canViewAllLeads ? 'all' : 'own'}';

const leadsResumenCacheTabla = '${SupabaseTables.leads}__campana_resumen';

LeadsResumen resumenDesdeLeads(Iterable<Lead> leads) {
  return LeadsResumen(
    total: leads.length,
    empresas: leads
        .where((lead) => (lead.empresa ?? '').trim().isNotEmpty)
        .length,
  );
}

LeadsResumen aplicarColaAResumen({
  required LeadsResumen base,
  required Iterable<SyncQueueItem> cola,
  required String eventoId,
}) {
  final inserts = leadQueueItemsForOverlay(cola).where(
    (item) =>
        item.operation == SyncOperation.insert &&
        item.payload['evento_id'] == eventoId,
  );
  var extraTotal = 0;
  var extraEmpresas = 0;
  for (final item in inserts) {
    extraTotal++;
    if ((item.payload['empresa'] as String? ?? '').trim().isNotEmpty) {
      extraEmpresas++;
    }
  }
  if (extraTotal == 0) return base;
  return LeadsResumen(
    total: base.total + extraTotal,
    empresas: base.empresas + extraEmpresas,
  );
}

/// RPC de conteos del evento de leads. Lo puede pedir todo el que lo abre
/// —incluido el externo autorizado—, porque devuelve conteos y no filas: el
/// recorte a "mis leads" es de la lista, no del resumen. Se cachea sin PII.
final leadsResumenRemotoProvider = FutureProvider.autoDispose
    .family<LeadsResumen, String>((ref, eventoId) async {
      final perfil = await ref.watch(currentPerfilProvider.future);
      if (perfil == null) {
        return const LeadsResumen(total: 0, empresas: 0);
      }
      final isOnline = ref.watch(isOnlineProvider);
      final cache = ref.watch(offlineReadCacheProvider);
      final filas = await cache.leerConRespaldo(
        tabla: leadsResumenCacheTabla,
        eventoId: eventoId,
        desdeServidor: () async {
          final remoto = await ref
              .watch(leadsRepositoryProvider)
              .obtenerResumenCampana(eventoId);
          return [LeadsResumen(total: remoto.total, empresas: remoto.empresas)];
        },
        aFila: (resumen) => resumen.toCacheMap(),
        desdeFila: LeadsResumen.fromMap,
        isOnline: isOnline,
      );
      return filas.isEmpty
          ? const LeadsResumen(total: 0, empresas: 0)
          : filas.first;
    });

/// Conteos del hub: RPC del evento de leads para internos, con cola local.
final leadsResumenLocalProvider = Provider.autoDispose
    .family<LeadsResumen?, String>((ref, eventoId) {
      final perfil = ref.watch(currentPerfilProvider).valueOrNull;
      if (perfil == null) return null;

      final cola = leadQueueItemsForOverlay(
        ref.watch(syncQueueServiceProvider),
      );
      final cache = ref.watch(offlineReadCacheProvider);

      final remoto = ref.watch(leadsResumenRemotoProvider(eventoId)).valueOrNull;
      final cacheados = cache.leerLocal(
        tabla: leadsResumenCacheTabla,
        eventoId: eventoId,
        desdeFila: LeadsResumen.fromMap,
      );
      final cacheado = cacheados == null || cacheados.isEmpty
          ? null
          : cacheados.first;
      final base = remoto ?? cacheado;
      if (base != null) {
        return aplicarColaAResumen(base: base, cola: cola, eventoId: eventoId);
      }

      // Sin resumen del servidor solo se puede contar lo que hay en caché, y
      // eso únicamente sirve si el perfil ve todos los leads: para `user` o
      // externo serían sus propias filas haciéndose pasar por el total de la
      // evento (de ahí los ceros del hub). Mejor dejarlo en "—".
      if (!perfil.canViewAllLeads) return null;

      final local = cache.leerLocal(
        tabla: leadsCacheTabla(true),
        eventoId: eventoId,
        desdeFila: Lead.fromMap,
      );
      final fusionados = fusionarLeadsConCola(
        servidor: local ?? const [],
        colaDeLeads: cola,
        eventoId: eventoId,
      );
      if (local == null && fusionados.isEmpty) return null;
      return resumenDesdeLeads(fusionados);
    });

/// Combina los leads del servidor con lo que sigue pendiente en la cola
/// offline (inserts y updates). Si el servidor no responde se sirve la última
/// copia en caché, para que la lista y el detalle funcionen sin conexión.
final leadsPorEventoProvider = FutureProvider.autoDispose
    .family<List<Lead>, String>((ref, eventoId) async {
      final repo = ref.watch(leadsRepositoryProvider);
      final perfil = await ref.watch(currentPerfilProvider.future);
      if (perfil == null) return const [];
      final isOnline = ref.watch(isOnlineProvider);
      final cacheTabla = leadsCacheTabla(perfil.canViewAllLeads);

      final cache = ref.watch(offlineReadCacheProvider);
      final servidor = await cache.leerConRespaldo(
        tabla: cacheTabla,
        eventoId: eventoId,
        desdeServidor: () => perfil.canViewAllLeads
            ? repo.listarPorEvento(eventoId)
            : repo.listarPorEventoYPerfil(eventoId, perfil.id),
        aFila: (lead) => lead.toCacheMap(),
        desdeFila: Lead.fromMap,
        isOnline: isOnline,
      );
      final servidorVisible = perfil.canViewAllLeads
          ? servidor
          : servidor.where((lead) => lead.perfilId == perfil.id).toList();
      if (!perfil.canViewAllLeads &&
          servidorVisible.length != servidor.length) {
        await cache.guardar(
          cacheTabla,
          eventoId,
          servidorVisible.map((lead) => lead.toCacheMap()).toList(),
        );
      }

      return fusionarLeadsConCola(
        servidor: servidorVisible,
        colaDeLeads: leadQueueItemsForOverlay(
          ref.watch(syncQueueServiceProvider),
        ),
        eventoId: eventoId,
      );
    });
