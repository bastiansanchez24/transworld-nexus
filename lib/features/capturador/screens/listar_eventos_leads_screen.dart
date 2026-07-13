import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/evento_lead.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/capturador_providers.dart';

class ListarEventosLeadsScreen extends ConsumerWidget {
  const ListarEventosLeadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventosAsync = ref.watch(eventosLeadsListProvider);
    final esAdmin = ref.watch(isAdminProvider);

    return AppScaffold(
      title: 'Capturador de leads',
      floatingActionButton: esAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push(RoutePaths.crearEventoLead),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo evento'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(eventosLeadsListProvider),
        child: eventosAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: 'No se pudieron cargar los eventos de leads.',
            onRetry: () => ref.invalidate(eventosLeadsListProvider),
          ),
          data: (eventos) {
            if (eventos.isEmpty) {
              return const EmptyStateView(
                icon: Icons.person_search_rounded,
                message: 'Todavía no hay eventos de captura creados.',
              );
            }
            return ListView.separated(
              padding: AppSpacing.screen,
              itemCount: eventos.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final evento = eventos[index];
                return _EventoLeadTile(
                  evento: evento,
                  esAdmin: esAdmin,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _EventoLeadTile extends StatelessWidget {
  const _EventoLeadTile({required this.evento, required this.esAdmin});

  final EventoLead evento;
  final bool esAdmin;

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat('dd/MM/yyyy').format(evento.fecha);
    final subtitulo = [
      fecha,
      if (evento.pais != null && evento.pais!.isNotEmpty) evento.pais,
      if (evento.tematica != null && evento.tematica!.isNotEmpty) evento.tematica,
    ].join(' · ');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(RoutePaths.usarEventoLead(evento.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.person_search_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      evento.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      subtitulo,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    if (evento.yaOcurrio)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Evento finalizado',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (esAdmin)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      context.push(RoutePaths.editarEventoLead(evento.id)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
