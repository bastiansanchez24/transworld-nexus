import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/eventos_leads_repository.dart';
import '../../../data/repositories/eventos_repository.dart';
import '../../../data/repositories/fijados_repository.dart';
import '../../../data/repositories/leads_repository.dart';
import '../../../data/repositories/registrados_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../fijados/providers/fijados_providers.dart';
import '../models/home_featured_item.dart';
import 'home_dashboard_providers.dart';

/// Ítems del header del home: fijados primero; el próximo evento al final.
final homeFeaturedItemsProvider =
    FutureProvider.autoDispose<List<HomeFeaturedItem>>((ref) async {
      ref.watch(authStateChangesProvider);
      // Dependencias para refrescar al fijar/desfijar.
      await ref.watch(eventosFijadosProvider.future);
      await ref.watch(campanasFijadasProvider.future);

      final fijadosRepo = ref.watch(fijadosRepositoryProvider);
      final eventoIds = await fijadosRepo.listarEventosFijadosOrdenados();
      final campanaIds = await fijadosRepo.listarCampanasFijadasOrdenadas();
      final dashboard = await ref.watch(homeDashboardProvider.future);
      final proximo = dashboard.proximoEvento;
      final fijados = <HomeFeaturedItem>[];

      if (eventoIds.isNotEmpty || campanaIds.isNotEmpty) {
        final eventosRepo = ref.watch(eventosRepositoryProvider);
        final campanasRepo = ref.watch(eventosLeadsRepositoryProvider);

        for (final id in eventoIds) {
          try {
            final evento = await eventosRepo.obtenerPorId(id);
            fijados.add(HomeFeaturedItem.eventoFijado(evento));
          } catch (_) {
            // Evento borrado o inaccesible: omitir.
          }
        }
        for (final id in campanaIds) {
          try {
            final campana = await campanasRepo.obtenerPorId(id);
            fijados.add(HomeFeaturedItem.campanaFijada(campana));
          } catch (_) {
            // Campaña borrada o inaccesible: omitir.
          }
        }
      }

      final items = ensamblarHomeFeaturedItems(
        fijados: fijados,
        proximo: proximo == null
            ? null
            : HomeFeaturedItem.proximoEvento(proximo),
      );

      if (items.isEmpty) return items;

      final registradosRepo = ref.watch(registradosRepositoryProvider);
      final campanasRepo = ref.watch(eventosLeadsRepositoryProvider);
      final leadsRepo = ref.watch(leadsRepositoryProvider);
      return Future.wait(
        items.map(
          (item) => _conMetricas(
            item: item,
            registradosRepo: registradosRepo,
            campanasRepo: campanasRepo,
            leadsRepo: leadsRepo,
          ),
        ),
      );
    });

Future<HomeFeaturedItem> _conMetricas({
  required HomeFeaturedItem item,
  required RegistradosRepository registradosRepo,
  required EventosLeadsRepository campanasRepo,
  required LeadsRepository leadsRepo,
}) async {
  try {
    if (item.kind == HomeFeaturedKind.campanaFijada) {
      final resumen = await leadsRepo.obtenerResumenCampana(item.id);
      return item.copyWith(leads: resumen.total);
    }

    final resumen = await registradosRepo.obtenerResumenPorEvento(item.id);
    var leads = 0;
    try {
      final campana = await campanasRepo.buscarPorNombre(item.nombre);
      if (campana != null) {
        leads = (await leadsRepo.obtenerResumenCampana(campana.id)).total;
      }
    } catch (_) {
      // Sin campaña homónima o sin permiso: leads queda en 0.
    }
    return item.copyWith(
      registrados: resumen.total,
      acreditados: resumen.acreditados,
      leads: leads,
    );
  } catch (_) {
    return item;
  }
}
