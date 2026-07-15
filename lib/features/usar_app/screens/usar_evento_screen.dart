import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/collapsing_nav.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/evento.dart';
import '../../auth/providers/auth_providers.dart';
import '../../eventos/providers/eventos_providers.dart';
import '../../registrados/providers/registrados_providers.dart';

/// Menú operativo de un evento: equivalente a `usar-app.tsx` / `UsarApp.tsx`
/// del proyecto legado, rediseñado con hero navy + acciones Nexus.
class UsarEventoScreen extends ConsumerStatefulWidget {
  const UsarEventoScreen({super.key, required this.eventoId});

  final String eventoId;

  @override
  ConsumerState<UsarEventoScreen> createState() => _UsarEventoScreenState();
}

class _UsarEventoScreenState extends ConsumerState<UsarEventoScreen> {
  @override
  Widget build(BuildContext context) {
    final eventoAsync = ref.watch(eventoByIdProvider(widget.eventoId));
    final esAdmin = ref.watch(isAdminProvider);
    final registradosAsync = ref.watch(
      registradosPorEventoProvider(widget.eventoId),
    );

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
                  final registrados = registradosAsync.valueOrNull;
                  final totalReg = registrados?.length;
                  final totalAcred = registrados
                      ?.where((r) => r.acreditado)
                      .length;

                  return Column(
                    children: [
                      Stack(
                        children: [
                          _EventoHero(evento: evento),
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
                              trailing: esAdmin
                                  ? _HeroNavButton(
                                      icon: Symbols.edit_rounded,
                                      onTap: () => context.push(
                                        RoutePaths.editarEvento(
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
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _MiniStat(
                                            value: totalReg?.toString() ?? '—',
                                            label: 'Registrados',
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _MiniStat(
                                            value:
                                                totalAcred?.toString() ?? '—',
                                            label: 'Acreditados',
                                            valueColor: AppColors.success,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Expanded(
                                          child: _MiniStat(
                                            value: '—',
                                            label: 'Leads',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    const SectionLabel('Acciones del evento'),
                                    const SizedBox(height: 10),
                                    ..._acciones(context).asMap().entries.map(
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

  List<Widget> _acciones(BuildContext context) {
    final id = widget.eventoId;
    return [
      NexusActionRow(
        icon: Symbols.person_add_rounded,
        title: 'Registrar asistente',
        onTap: () => context.push(RoutePaths.registrar(id)),
      ),
      NexusActionRow(
        icon: Symbols.link_rounded,
        title: 'Registro por cliente',
        subtitle: 'Compartir enlace público / cargar Excel',
        onTap: () => context.push(RoutePaths.registroPorCliente(id)),
      ),
      NexusActionRow(
        icon: Symbols.how_to_reg_rounded,
        title: 'Acreditar (manual)',
        onTap: () => context.push(RoutePaths.acreditarConfirmado(id)),
      ),
      NexusActionRow(
        icon: Symbols.qr_code_scanner_rounded,
        title: 'Acreditar por QR',
        onTap: () => context.push(RoutePaths.acreditarQr(id)),
      ),
      NexusActionRow(
        icon: Symbols.list_alt_rounded,
        title: 'Ver registrados',
        onTap: () => context.push(RoutePaths.verRegistrados(id)),
      ),
      NexusActionRow(
        icon: Symbols.bar_chart_rounded,
        title: 'KPI del evento',
        onTap: () => context.push(RoutePaths.kpi(id)),
      ),
      NexusActionRow(
        icon: Symbols.download_rounded,
        title: 'Exportar a Excel',
        onTap: () => context.push(RoutePaths.exportar(id)),
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

class _EventoHero extends StatelessWidget {
  const _EventoHero({required this.evento});

  final Evento evento;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    // Reserva espacio para los botones del CollapsingNavOverlay (titleZone).
    final fechaChip = DateFormat(
      "EEEE d · MMMM yyyy",
      'es',
    ).format(evento.fecha);
    final lugar = [
      if (evento.lugar != null && evento.lugar!.isNotEmpty) evento.lugar,
      if (evento.pais != null && evento.pais!.isNotEmpty) evento.pais,
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
        topPad + CollapsingNavMetrics.titleZone + 8,
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
          if (lugar.isNotEmpty) ...[
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
                    lugar,
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.value,
    required this.label,
    this.valueColor = AppColors.ink,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.shadowRest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
