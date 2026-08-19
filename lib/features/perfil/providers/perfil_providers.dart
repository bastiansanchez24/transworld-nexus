import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/lead.dart';
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

  final results = await Future.wait([
    leadsRepo.contarPorPerfil(uid),
    registradosRepo.contarPorIngresadoPor(uid),
    registradosRepo.contarPorAcreditadoPor(uid),
    eventosRepo.contarCreadosPor(uid),
  ]);

  return MiPerfilStats(
    leadsCapturados: results[0],
    asistentesRegistrados: results[1],
    acreditaciones: results[2],
    eventosCreados: results[3],
  );
});

final misLeadsProvider = FutureProvider.autoDispose<List<Lead>>((ref) async {
  final perfil = await ref.watch(currentPerfilProvider.future);
  if (perfil == null) return const [];
  return ref.watch(leadsRepositoryProvider).listarPorPerfil(perfil.id);
});
