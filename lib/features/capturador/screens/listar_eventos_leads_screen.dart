import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/collapsing_nav.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/evento_lead.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/capturador_providers.dart';

class ListarEventosLeadsScreen extends ConsumerStatefulWidget {
  const ListarEventosLeadsScreen({super.key});

  @override
  ConsumerState<ListarEventosLeadsScreen> createState() =>
      _ListarEventosLeadsScreenState();
}

class _ListarEventosLeadsScreenState
    extends ConsumerState<ListarEventosLeadsScreen> {
  String _filtro = 'Todos';

  Widget _buildFilterBar() {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: FilterChipBar(
          options: const ['Todos', 'Activos', 'Finalizados'],
          selected: _filtro,
          onSelected: (v) => setState(() => _filtro = v),
        ),
      ),
    );
  }

  List<EventoLead> _filtrar(List<EventoLead> eventos) {
    return switch (_filtro) {
      'Activos' => eventos.where((e) => !e.yaOcurrio).toList(),
      'Finalizados' => eventos.where((e) => e.yaOcurrio).toList(),
      _ => eventos,
    };
  }

  @override
  Widget build(BuildContext context) {
    final eventosAsync = ref.watch(eventosLeadsListProvider);
    final esAdmin = ref.watch(isAdminProvider);

    return CollapsingScrollScaffold(
      title: 'Leads',
      onRefresh: () async => ref.invalidate(eventosLeadsListProvider),
      pinnedContent: _buildFilterBar(),
      floatingActionButton: esAdmin
          ? NexusExtendedFab(
              label: 'Nuevo lead',
              icon: Symbols.add_rounded,
              onPressed: () => context.push(RoutePaths.crearEventoLead),
            )
          : null,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Leads', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 2),
                const Text(
                  'Capturador de leads por campaña',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        ...eventosAsync.when(
          loading: () => [const SliverFillRemaining(child: LoadingView())],
          error: (e, _) => [
            SliverFillRemaining(
              child: ErrorView(
                message: 'No se pudieron cargar los eventos de leads.',
                onRetry: () => ref.invalidate(eventosLeadsListProvider),
              ),
            ),
          ],
          data: (eventos) {
            final filtrados = _filtrar(eventos);
            if (eventos.isEmpty) {
              return [
                const SliverFillRemaining(
                  child: EmptyStateView(
                    icon: Icons.person_search_rounded,
                    message: 'Todavía no hay eventos de captura creados.',
                  ),
                ),
              ];
            }
            if (filtrados.isEmpty) {
              return [
                const SliverFillRemaining(
                  child: EmptyStateView(
                    icon: Icons.filter_list_off_rounded,
                    message: 'No hay campañas en este filtro.',
                  ),
                ),
              ];
            }
            return [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                sliver: SliverList.separated(
                  itemCount: filtrados.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final evento = filtrados[index];
                    return StaggeredListItem(
                      index: index,
                      child: _LeadCampaignCard(
                        evento: evento,
                        esAdmin: esAdmin,
                      ),
                    );
                  },
                ),
              ),
            ];
          },
        ),
      ],
    );
  }
}

class _LeadCampaignCard extends StatelessWidget {
  const _LeadCampaignCard({required this.evento, required this.esAdmin});

  final EventoLead evento;
  final bool esAdmin;

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat('dd/MM/yyyy').format(evento.fecha);
    final meta = [
      fecha,
      if (evento.pais != null && evento.pais!.isNotEmpty) evento.pais,
      if (evento.tematica != null && evento.tematica!.isNotEmpty)
        evento.tematica,
    ].join(' · ');
    final finalizado = evento.yaOcurrio;

    return Pressable(
      onTap: () => context.push(RoutePaths.usarEventoLead(evento.id)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.shadowRest,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: finalizado ? AppColors.background : AppColors.tintNavy,
                borderRadius: BorderRadius.circular(AppRadius.tile),
              ),
              child: Icon(
                Symbols.person_search_rounded,
                color: finalizado ? AppColors.textTertiary : AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    evento.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  StatusChip(
                    label: finalizado ? 'Evento finalizado' : 'Activo',
                    variant: finalizado
                        ? StatusChipVariant.danger
                        : StatusChipVariant.success,
                  ),
                ],
              ),
            ),
            if (esAdmin)
              Pressable(
                scale: 0.9,
                onTap: () =>
                    context.push(RoutePaths.editarEventoLead(evento.id)),
                child: const Icon(
                  Symbols.edit_rounded,
                  color: AppColors.chevronMuted,
                  size: 20,
                ),
              )
            else
              const Icon(
                Symbols.chevron_right_rounded,
                color: AppColors.chevronMuted,
              ),
          ],
        ),
      ),
    );
  }
}
