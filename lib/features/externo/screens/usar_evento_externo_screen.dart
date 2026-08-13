import 'dart:async';

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
import '../../../core/widgets/evento_hero_banner.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../core/widgets/nexus_toast.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/permissions_bootstrap.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/evento.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../eventos/providers/eventos_providers.dart';
import '../../registrados/providers/registrados_providers.dart';
import '../providers/externo_dashboard_provider.dart';

/// Vista operativa reducida para usuarios externos: hero, resumen propio y QR.
class UsarEventoExternoScreen extends ConsumerStatefulWidget {
  const UsarEventoExternoScreen({super.key, required this.eventoId});

  final String eventoId;

  @override
  ConsumerState<UsarEventoExternoScreen> createState() =>
      _UsarEventoExternoScreenState();
}

class _UsarEventoExternoScreenState
    extends ConsumerState<UsarEventoExternoScreen> {
  bool _bloqueoManejado = false;

  @override
  void initState() {
    super.initState();
    unawaited(_precargarPadron(widget.eventoId));
  }

  @override
  void didUpdateWidget(covariant UsarEventoExternoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventoId != widget.eventoId) {
      unawaited(_precargarPadron(widget.eventoId));
    }
  }

  /// Conserva disponible el padrón en la caché offline sin usarlo para
  /// estadísticas del dashboard. El escáner comparte este mismo provider.
  Future<void> _precargarPadron(String eventoId) async {
    try {
      await ref.read(registradosPorEventoProvider(eventoId).future);
    } catch (_) {
      // El escáner mostrará su estado offline/error si tampoco existe caché.
    }
  }

  Future<void> _manejarBloqueoTotal() async {
    if (_bloqueoManejado || !mounted) return;
    _bloqueoManejado = true;
    NexusToast.show(context, 'No hay eventos operativos disponibles');
    await ref.read(authRepositoryProvider).cerrarSesion();
    if (!mounted) return;
    context.go(RoutePaths.eventoFinalizado);
  }

  Future<void> _cerrarSesion() async {
    await ref.read(authRepositoryProvider).cerrarSesion();
    if (!mounted) return;
    context.go(RoutePaths.login);
  }

  Future<void> _cambiarEvento(Evento destino) async {
    if (destino.id == widget.eventoId) return;

    final anteriorId = widget.eventoId;
    try {
      await cambiarEventoActivoExterno(ref, destino.id);
      ref.invalidate(eventoByIdProvider(anteriorId));
      ref.invalidate(eventoByIdProvider(destino.id));
      if (!mounted) return;
      context.go(RoutePaths.externoEvento(destino.id));
    } catch (e) {
      if (!mounted) return;
      NexusToast.show(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _mostrarSelectorEventos() async {
    final autorizados =
        ref.read(externoEventosAutorizadosProvider).valueOrNull ?? [];
    if (autorizados.length <= 1) return;

    final elegido = await showModalBottomSheet<Evento>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Cambiar evento',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: autorizados.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (context, index) {
                    final e = autorizados[index];
                    final activo = e.id == widget.eventoId;
                    final operable = eventoExternoOperable(e);
                    return ListTile(
                      enabled: operable || activo,
                      leading: Icon(
                        activo
                            ? Symbols.check_circle_rounded
                            : Symbols.event_rounded,
                        color: activo
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      title: Text(
                        e.nombre,
                        style: TextStyle(
                          fontWeight: activo
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: operable || activo
                              ? AppColors.ink
                              : AppColors.textTertiary,
                        ),
                      ),
                      subtitle: !operable
                          ? Text(
                              e.yaOcurrio ? 'Finalizado' : 'Inactivo',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            )
                          : null,
                      onTap: operable ? () => Navigator.of(ctx).pop(e) : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (elegido != null) {
      await _cambiarEvento(elegido);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventoAsync = ref.watch(eventoByIdProvider(widget.eventoId));
    final autorizadosAsync = ref.watch(externoEventosAutorizadosProvider);
    final statsAsync = ref.watch(externoDashboardProvider);
    final puedeCambiar = (autorizadosAsync.valueOrNull?.length ?? 0) > 1;

    ref.listen(externoEventoBloqueadoProvider, (prev, next) {
      if (next == true) _manejarBloqueoTotal();
    });

    final bloqueado = ref.watch(externoEventoBloqueadoProvider);
    if (bloqueado == true) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _manejarBloqueoTotal(),
      );
    }

    // Si esta ruta quedó en un evento no operable pero hay otros, el router
    // redirige; aquí sincronizamos override si el id de ruta es autorizado.
    ref.listen(externoEventosAutorizadosProvider, (_, next) {
      final lista = next.valueOrNull;
      if (lista == null) return;
      Evento? match;
      for (final e in lista) {
        if (e.id == widget.eventoId) {
          match = e;
          break;
        }
      }
      if (match == null) return;
      final override = ref.read(externoEventoActivoOverrideProvider);
      if (override != widget.eventoId &&
          ref.read(currentPerfilProvider).valueOrNull?.eventoAsignadoId !=
              widget.eventoId) {
        ref.read(externoEventoActivoOverrideProvider.notifier).state =
            widget.eventoId;
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PermissionsBootstrap(
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
                    return Column(
                      children: [
                        Stack(
                          children: [
                            _EventoExternoHero(
                              evento: evento,
                              puedeCambiar: puedeCambiar,
                              onTapNombre: puedeCambiar
                                  ? _mostrarSelectorEventos
                                  : null,
                            ),
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: CollapsingNavOverlay(
                                scrollOffset: 0,
                                title: evento.nombre,
                                style: CollapsingNavStyle.detail,
                                alwaysShowActions: true,
                                trailing: _HeroNavButton(
                                  key: const Key('externo_logout_button'),
                                  icon: Symbols.logout_rounded,
                                  tooltip: 'Cerrar sesión',
                                  onTap: _cerrarSesion,
                                ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _ExternoStatsCards(
                                        statsAsync: statsAsync,
                                        onRetry: () => ref.invalidate(
                                          externoDashboardProvider,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      StaggeredListItem(
                                        index: 0,
                                        child: _PrimaryActionCard(
                                          key: const Key(
                                            'externo_scan_qr_button',
                                          ),
                                          icon: Symbols.qr_code_scanner_rounded,
                                          title: 'Escanear QR',
                                          subtitle:
                                              'Acredita asistentes o captura leads',
                                          onTap: () => context.push(
                                            RoutePaths.acreditarQr(
                                              widget.eventoId,
                                            ),
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
      ),
    );
  }
}

class _HeroNavButton extends StatelessWidget {
  const _HeroNavButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Pressable(
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

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _EventoExternoHero extends StatelessWidget {
  const _EventoExternoHero({
    required this.evento,
    required this.puedeCambiar,
    this.onTapNombre,
  });

  final Evento evento;
  final bool puedeCambiar;
  final VoidCallback? onTapNombre;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final fechaChip = DateFormat(
      "EEEE d · MMMM yyyy",
      'es',
    ).format(evento.fecha);
    final lugar = [
      if (evento.lugar != null && evento.lugar!.isNotEmpty) evento.lugar,
      if (evento.direccion != null && evento.direccion!.isNotEmpty)
        evento.direccion,
      if (evento.pais != null && evento.pais!.isNotEmpty) evento.pais,
    ].join(' · ');

    final nombreWidget = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            evento.nombre,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.3,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (puedeCambiar) ...[
          const SizedBox(width: 6),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(
              Symbols.expand_more_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ],
    );

    return EventoHeroBanner(
      imagenUrl: evento.imagenUrl,
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
          if (onTapNombre != null)
            Pressable(scale: 0.98, onTap: onTapNombre, child: nombreWidget)
          else
            nombreWidget,
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

class _ExternoStatsCards extends StatelessWidget {
  const _ExternoStatsCards({required this.statsAsync, required this.onRetry});

  final AsyncValue<ExternoDashboardData> statsAsync;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final stats = statsAsync.valueOrNull;
    final eventos = stats?.eventosAutorizados.toString() ?? '—';
    final leads = stats == null
        ? '—'
        : stats.esResumenParcial
        ? (stats.leadsCapturados == 0 ? '—' : '${stats.leadsCapturados}+')
        : stats.leadsCapturados.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: stats == null && statsAsync.isLoading
              ? 'Cargando estadísticas personales'
              : null,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: StatCard(
                    key: const Key('externo_stat_eventos'),
                    value: eventos,
                    label: 'Eventos con acceso',
                    icon: Symbols.calendar_month_rounded,
                    tint: AppColors.tintNavy,
                    iconColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    key: const Key('externo_stat_leads'),
                    value: leads,
                    label: 'Leads capturados',
                    icon: Symbols.person_search_rounded,
                    tint: AppColors.successTint,
                    iconColor: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (stats?.esResumenParcial == true) ...[
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(
                Symbols.info_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Resumen parcial: se muestran las capturas pendientes del dispositivo.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (statsAsync.hasError) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              color: AppColors.dangerTint,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(
                  Symbols.error_rounded,
                  size: 18,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'No pudimos actualizar tu resumen.',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('Reintentar')),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Pressable(
        scale: 0.98,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.headerGradient,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppColors.shadowFab,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: Colors.white, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Symbols.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
