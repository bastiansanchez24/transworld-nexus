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
  final _searchController = TextEditingController();
  String _query = '';
  String _filtro = 'Todos';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<EventoLead> _filtrar(List<EventoLead> eventos) {
    final porEstado = switch (_filtro) {
      'Activos' => eventos.where((e) => !e.yaOcurrio).toList(),
      'Finalizados' => eventos.where((e) => e.yaOcurrio).toList(),
      _ => eventos,
    };

    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return porEstado;
    return porEstado.where((e) {
      final pais = (e.pais ?? '').toLowerCase();
      final tematica = (e.tematica ?? '').toLowerCase();
      return e.nombre.toLowerCase().contains(q) ||
          pais.contains(q) ||
          tematica.contains(q);
    }).toList();
  }

  Widget _buildSearchField() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.input),
        boxShadow: AppColors.shadowRest,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v),
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.ink,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar campaña…',
          hintStyle: const TextStyle(color: AppColors.placeholder),
          prefixIcon: const Icon(
            Symbols.search_rounded,
            color: AppColors.placeholder,
            size: 20,
          ),
          filled: true,
          fillColor: AppColors.surface,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide:
                const BorderSide(color: AppColors.primaryLight, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedControls({required bool puedeCrear}) {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(child: _buildSearchField()),
              if (puedeCrear) ...[
                const SizedBox(width: 8),
                PinnedSearchActionButton(
                  icon: Symbols.add_rounded,
                  onTap: () => context.push(RoutePaths.crearEventoLead),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: FilterChipBar(
                options: const ['Todos', 'Activos', 'Finalizados'],
                selected: _filtro,
                onSelected: (v) => setState(() => _filtro = v),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({int? total, int? proximos}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Captura de Leads',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 2),
        const Text(
          'Registre campañas y capture oportunidades potenciales de negocio.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        if (total != null && proximos != null) ...[
          const SizedBox(height: 6),
          Text(
            '$total campañas · $proximos próximas',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventosAsync = ref.watch(eventosLeadsListProvider);
    final puedeCrear = ref.watch(canCreateContentProvider);

    return CollapsingScrollScaffold(
      title: 'Captura de Leads',
      onRefresh: () async => ref.invalidate(eventosLeadsListProvider),
      pinnedContent: _buildPinnedControls(puedeCrear: puedeCrear),
      pinnedContentHeight: 112,
      scrollResetToken: '$_query|$_filtro',
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: eventosAsync.when(
              loading: () => _buildHeader(),
              error: (_, _) => _buildHeader(),
              data: (eventos) {
                final proximos = eventos.where((e) => !e.yaOcurrio).length;
                return _buildHeader(
                  total: eventos.length,
                  proximos: proximos,
                );
              },
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
              final porBusqueda = _query.trim().isNotEmpty;
              return [
                SliverFillRemaining(
                  child: EmptyStateView(
                    icon: porBusqueda
                        ? Icons.search_off_rounded
                        : Icons.filter_list_off_rounded,
                    message: porBusqueda
                        ? 'No hay campañas que coincidan con la búsqueda.'
                        : 'No hay campañas en este filtro.',
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
                        puedeEditar: puedeCrear,
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
  const _LeadCampaignCard({
    required this.evento,
    required this.puedeEditar,
  });

  final EventoLead evento;
  final bool puedeEditar;

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
            if (puedeEditar)
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
