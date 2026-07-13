import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/evento.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/eventos_providers.dart';

class ListarEventosScreen extends ConsumerWidget {
  const ListarEventosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventosAsync = ref.watch(eventosListProvider);
    final esAdmin = ref.watch(isAdminProvider);

    return AppScaffold(
      title: 'Eventos',
      floatingActionButton: esAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push(RoutePaths.crearEvento),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo evento'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(eventosListProvider),
        child: eventosAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: 'No se pudieron cargar los eventos.',
            onRetry: () => ref.invalidate(eventosListProvider),
          ),
          data: (eventos) {
            if (eventos.isEmpty) {
              return const EmptyStateView(
                icon: Icons.event_busy_rounded,
                message: 'Todavía no hay eventos creados.',
              );
            }
            return ListView.separated(
              padding: AppSpacing.screen,
              itemCount: eventos.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final evento = eventos[index];
                return _EventoTile(
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

class _EventoTile extends StatelessWidget {
  const _EventoTile({required this.evento, required this.esAdmin});

  final Evento evento;
  final bool esAdmin;

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat('dd/MM/yyyy').format(evento.fecha);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(RoutePaths.usarEvento(evento.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: evento.activo
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.event_rounded,
                  color: evento.activo ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(evento.nombre,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('$fecha · ${evento.lugar ?? evento.pais ?? ''}',
                        style: const TextStyle(color: AppColors.textSecondary)),
                    if (evento.yaOcurrio)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Evento finalizado',
                          style: TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
              if (esAdmin)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      context.push(RoutePaths.editarEvento(evento.id)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
