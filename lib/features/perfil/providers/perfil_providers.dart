import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../data/models/lead.dart';
import '../../../data/offline/offline_cache_tables.dart';
import '../../../data/offline/offline_read_cache.dart';
import '../../../data/repositories/eventos_repository.dart';
import '../../../data/repositories/leads_repository.dart';
import '../../../data/repositories/registrados_repository.dart';
import '../../auth/providers/auth_providers.dart';

class MiPerfilStats {
  const MiPerfilStats({
    required this.leadsCapturados,
    required this.asistentesRegistrados,
    required this.acreditaciones,
    required this.eventosCreados,
  });

  final int leadsCapturados;
  final int asistentesRegistrados;
  final int acreditaciones;
  final int eventosCreados;

  factory MiPerfilStats.fromCacheMap(Map<String, dynamic> map) {
    int leer(String clave) => (map[clave] as num?)?.toInt() ?? 0;
    return MiPerfilStats(
      leadsCapturados: leer('leads_capturados'),
      asistentesRegistrados: leer('asistentes_registrados'),
      acreditaciones: leer('acreditaciones'),
      eventosCreados: leer('eventos_creados'),
    );
  }

  Map<String, dynamic> toCacheMap() => {
    'leads_capturados': leadsCapturados,
    'asistentes_registrados': asistentesRegistrados,
    'acreditaciones': acreditaciones,
    'eventos_creados': eventosCreados,
  };
}

final miPerfilStatsProvider = FutureProvider.autoDispose<MiPerfilStats>((
  ref,
) async {
  final perfil = await ref.watch(currentPerfilProvider.future);
  if (perfil == null) {
    return const MiPerfilStats(
      leadsCapturados: 0,
      asistentesRegistrados: 0,
      acreditaciones: 0,
      eventosCreados: 0,
    );
  }

  final uid = perfil.id;
  final leadsRepo = ref.watch(leadsRepositoryProvider);
  final registradosRepo = ref.watch(registradosRepositoryProvider);
  final eventosRepo = ref.watch(eventosRepositoryProvider);

  final filas = await ref
      .watch(offlineReadCacheProvider)
      .leerConRespaldoGlobal(
        tabla: OfflineCacheTables.perfilStats,
        desdeServidor: () async {
          final results = await Future.wait([
            leadsRepo.contarPorPerfil(uid),
            registradosRepo.contarPorIngresadoPor(uid),
            registradosRepo.contarPorAcreditadoPor(uid),
            eventosRepo.contarCreadosPor(uid),
          ]);
          return [
            MiPerfilStats(
              leadsCapturados: results[0],
              asistentesRegistrados: results[1],
              acreditaciones: results[2],
              eventosCreados: results[3],
            ),
          ];
        },
        aFila: (stats) => stats.toCacheMap(),
        desdeFila: MiPerfilStats.fromCacheMap,
        isOnline: ref.watch(isOnlineProvider),
      );

  return filas.isEmpty
      ? const MiPerfilStats(
          leadsCapturados: 0,
          asistentesRegistrados: 0,
          acreditaciones: 0,
          eventosCreados: 0,
        )
      : filas.first;
});

final misLeadsProvider = FutureProvider.autoDispose<List<Lead>>((ref) async {
  final perfil = await ref.watch(currentPerfilProvider.future);
  if (perfil == null) return const [];
  final repo = ref.watch(leadsRepositoryProvider);
  return ref
      .watch(offlineReadCacheProvider)
      .leerConRespaldoGlobal(
        tabla: OfflineCacheTables.misLeads,
        desdeServidor: () => repo.listarPorPerfil(perfil.id),
        aFila: (lead) => lead.toCacheMap(),
        desdeFila: Lead.fromMap,
        isOnline: ref.watch(isOnlineProvider),
      );
});
