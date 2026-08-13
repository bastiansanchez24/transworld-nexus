import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/router/refresh_on_visible.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/collapsing_nav.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/sync_conflict_listener.dart';
import '../../../data/models/evento_lead.dart';
import '../../../data/offline/sync_queue_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/capturador_providers.dart';

/// Hub operativo de un evento de captura de leads.
class UsarEventoLeadScreen extends ConsumerStatefulWidget {
  const UsarEventoLeadScreen({super.key, required this.eventoId});

  final String eventoId;

  @override
  ConsumerState<UsarEventoLeadScreen> createState() =>
      _UsarEventoLeadScreenState();
}

class _UsarEventoLeadScreenState extends ConsumerState<UsarEventoLeadScreen>
    with RefreshOnVisible {
  @override
  String get refreshWhenLocation => RoutePaths.usarEventoLead(widget.eventoId);

  @override
  void onBecomeVisible() {
    ref.invalidate(eventoLeadByIdProvider(widget.eventoId));
    ref.invalidate(leadsResumenRemotoProvider(widget.eventoId));
  }

  @override
  Widget build(BuildContext context) {
    final eventoAsync = ref.watch(eventoLeadByIdProvider(widget.eventoId));
    final puedeEditar = ref.watch(canCreateContentProvider);
    final puedeExportar = ref.watch(canExportDataProvider);
    final conflictos = ref.watch(syncConflictsProvider).length;
    final resumen = ref.watch(leadsResumenLocalProvider(widget.eventoId));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: eventoAsync.when(
                loading: () => const LoadingView(),
                error: (e, _) =>
                    const ErrorView(message: 'No se pudo cargar el evento.'),
                data: (evento) {
                  final totalLeads = resumen?.total;
                  final empresas = resumen?.empresas;

                  return Column(
                    children: [
                      Stack(
                        children: [
                          _EventoLeadHero(evento: evento),
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: CollapsingNavOverlay(
                              scrollOffset: 0,
                              title: evento.nombre,
                              style: CollapsingNavStyle.detail,
                              alwaysShowActions: true,
                              leading: _HeroNavButton(
                                icon: Symbols.arrow_back_ios_new_rounded,
                                onTap: () => context.pop(),
                              ),
                              trailing: puedeEditar
                                  ? _HeroNavButton(
                                      icon: Symbols.edit_rounded,
                                      onTap: () => context.push(
                                        RoutePaths.editarEventoLead(
                                          widget.eventoId,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: CustomScrollView(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  18,
                                  20,
                                  32,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: StatCard(
                                              key: const Key(
                                                'campana_stat_leads',
                                              ),
                                              value:
                                                  totalLeads?.toString() ?? '—',
                                              label: 'Leads capturados',
                                              icon:
                                                  Symbols.person_search_rounded,
                                              tint: AppColors.successTint,
                                              iconColor: AppColors.success,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: StatCard(
                                              key: const Key(
                                                'campana_stat_empresas',
                                              ),
                                              value:
                                                  empresas?.toString() ?? '—',
                                              label: 'Empresas',
                                              icon: Symbols.apartment_rounded,
                                              tint: AppColors.tintNavy,
                                              iconColor: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    const SectionLabel('Acciones del evento'),
                                    const SizedBox(height: 10),
                                    ..._acciones(
                                      context,
                                      puedeExportar: puedeExportar,
                                      conflictos: conflictos,
                                    ).asMap().entries.map(
                                      (entry) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: StaggeredListItem(
                                          index: entry.key,
                                          child: entry.value,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 40),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _acciones(
    BuildContext context, {
    required bool puedeExportar,
    required int conflictos,
  }) {
    final id = widget.eventoId;
    return [
      NexusActionRow(
        icon: Symbols.person_add_rounded,
        title: 'Capturar lead',
        subtitle: 'Registrar un nuevo cliente',
        onTap: () => context.push(RoutePaths.capturarLead(id)),
      ),
      NexusActionRow(
        icon: Symbols.list_alt_rounded,
        title: 'Ver leads',
        subtitle: 'Listado de clientes capturados',
        onTap: () => context.push(RoutePaths.verLeads(id)),
      ),
      if (puedeExportar)
        NexusActionRow(
          icon: Symbols.download_rounded,
          title: 'Exportar a Excel',
          subtitle: 'Descargar leads del evento',
          onTap: () => context.push(RoutePaths.exportarLeads(id)),
        ),
      if (conflictos > 0)
        NexusActionRow(
          icon: Symbols.warning_rounded,
          title: 'Conflictos de sincronización',
          subtitle: '$conflictos pendiente(s) de revisar',
          onTap: () => showSyncConflictsSheet(context, ref),
        ),
    ];
  }
}

class _HeroNavButton extends StatelessWidget {
  const _HeroNavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.9,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _EventoLeadHero extends StatelessWidget {
  const _EventoLeadHero({required this.evento});

  final EventoLead evento;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final fechaChip = DateFormat(
      "EEEE d · MMMM yyyy",
      'es',
    ).format(evento.fecha);
    final meta = [
      if (evento.pais != null && evento.pais!.isNotEmpty) evento.pais,
      if (evento.tematica != null && evento.tematica!.isNotEmpty)
        evento.tematica,
    ].join(' · ');

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.header),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        topPad +
            CollapsingNavMetrics.gapDetail * 2 +
            CollapsingNavMetrics.titleZone +
            8,
        20,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Text(
              fechaChip,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            evento.nombre,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.3,
              letterSpacing: -0.3,
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Symbols.location_on_rounded,
                  size: 16,
                  color: Color(0xBFFFFFFF),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    meta,
                    style: const TextStyle(
                      color: Color(0xBFFFFFFF),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
