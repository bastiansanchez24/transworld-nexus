import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/eventos_leads_repository.dart';
import '../../../data/repositories/eventos_repository.dart';
import '../../../data/repositories/fijados_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../fijados/providers/fijados_providers.dart';
import '../models/home_featured_item.dart';
import 'home_dashboard_providers.dart';

/// Ítems del header del home: próximo evento seguido de los fijados.
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
      final items = <HomeFeaturedItem>[
        if (proximo != null) HomeFeaturedItem.proximoEvento(proximo),
      ];

      if (eventoIds.isNotEmpty || campanaIds.isNotEmpty) {
        final eventosRepo = ref.watch(eventosRepositoryProvider);
        final campanasRepo = ref.watch(eventosLeadsRepositoryProvider);

        for (final id in eventoIds) {
          // El próximo evento permanece primero y no se repite si también está
          // fijado por el usuario.
          if (id == proximo?.id) continue;
          try {
            final evento = await eventosRepo.obtenerPorId(id);
            items.add(HomeFeaturedItem.eventoFijado(evento));
          } catch (_) {
            // Evento borrado o inaccesible: omitir.
          }
        }
        for (final id in campanaIds) {
          try {
            final campana = await campanasRepo.obtenerPorId(id);
            items.add(HomeFeaturedItem.campanaFijada(campana));
          } catch (_) {
            // Campaña borrada o inaccesible: omitir.
          }
        }
      }

      return items;
    });
