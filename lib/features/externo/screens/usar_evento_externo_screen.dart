import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/browser_theme_color.dart';
import '../../../core/theme/tw_tokens.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/evento_hero_banner.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/permissions_bootstrap.dart';
import '../../../core/widgets/tw_components.dart';
import '../../../core/widgets/tw_detail_scaffold.dart';
import '../../../core/widgets/tw_toast.dart';
import '../../../data/models/capturar_lead_route_extra.dart';
import '../../../data/models/evento.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../capturador/services/evento_lead_interno_service.dart';
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
    // Defensa en profundidad sobre `externoEventoBloqueadoProvider`: cerrar la
    // sesión es irreversible sin red, así que solo se hace cuando el servidor
    // pudo confirmar que no queda ningún evento operable.
    if (!ref.read(isOnlineProvider)) return;
    _bloqueoManejado = true;
    TwToast.info(context, 'No hay eventos operativos disponibles');
    await ref.read(authRepositoryProvider).cerrarSesion();
    if (!mounted) return;
    context.go(RoutePaths.eventoFinalizado);
  }

  void _abrirMiPerfil() => context.push(RoutePaths.perfil);

  /// Menú de cuenta del externo: su ficha, el estado de sincronización, las
  /// actualizaciones si la plataforma las soporta, y cerrar sesión.
  ///
  /// Sin campana: el externo no recibe notificaciones y una bandeja siempre
  /// vacía solo genera dudas.
  Future<void> _mostrarMenuCuenta() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: TwColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 18, 16, 4),
              child: TwSectionLabel('Ajustes', top: 0),
            ),
            // Desplazable: en pantallas cortas los cuatro accesos no caben y
            // la hoja desbordaba.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    TwActionTile(
                      icon: Symbols.person_rounded,
                      iconStyle: TwIconBoxStyle.blueTint,
                      title: 'Mi perfil',
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _abrirMiPerfil();
                      },
                    ),
                    const SizedBox(height: 10),
                    TwActionTile(
                      icon: Symbols.sync_rounded,
                      iconStyle: TwIconBoxStyle.blueTint,
                      title: 'Sincronización',
                      onTap: () {
                        Navigator.of(ctx).pop();
                        context.push(RoutePaths.sincronizacion);
                      },
                    ),
                    if (!kIsWeb) ...[
                      const SizedBox(height: 10),
                      TwActionTile(
                        icon: Symbols.system_update_rounded,
                        iconStyle: TwIconBoxStyle.blueTint,
                        title: 'Actualizaciones',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          context.push(RoutePaths.actualizaciones);
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                    TwActionTile(
                      key: const Key('externo_logout_button'),
                      icon: Symbols.logout_rounded,
                      iconStyle: TwIconBoxStyle.amberTint,
                      title: 'Cerrar sesión',
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _cerrarSesion();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  /// Abre el formulario de captura sobre la actividad del evento activo.
  ///
  /// Sin red la actividad no se puede crear, así que si el snapshot no la
  /// guardó se dice explícitamente en vez de dejar un formulario que no podría
  /// guardarse en ningún sitio.
  Future<void> _capturarLead(Evento evento) async {
    try {
      final actividad = await obtenerOCrearEventoLeadInterno(ref, evento);
      if (!mounted) return;
      await context.push(
        RoutePaths.capturarLead(actividad.id, desdeEvento: evento.id),
        extra: CapturarLeadRouteExtra(eventoRegistroId: evento.id),
      );
    } catch (e) {
      if (!mounted) return;
      TwToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
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
      TwToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _mostrarSelectorEventos() async {
    final autorizados =
        ref.read(externoEventosAutorizadosProvider).valueOrNull ?? [];
    if (autorizados.length <= 1) return;

    final elegido = await showModalBottomSheet<Evento>(
      context: context,
      backgroundColor: TwColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 18, 16, 4),
                child: TwSectionLabel('Cambiar evento', top: 0),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: autorizados.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final e = autorizados[index];
                    final activo = e.id == widget.eventoId;
                    final operable = eventoExternoOperable(e);
                    return Opacity(
                      opacity: operable || activo ? 1 : 0.5,
                      child: TwActionTile(
                        icon: activo
                            ? Symbols.check_circle_rounded
                            : Symbols.event_rounded,
                        iconStyle: activo
                            ? TwIconBoxStyle.brand
                            : TwIconBoxStyle.blueTint,
                        title: e.nombre,
                        subtitle: operable
                            ? null
                            : (e.yaOcurrio ? 'Finalizado' : 'Inactivo'),
                        onTap: () {
                          if (!operable) return;
                          Navigator.of(ctx).pop(e);
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
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

    return BrowserThemeColor(
      color: TwColors.bg,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: PermissionsBootstrap(
          child: Scaffold(
            backgroundColor: TwColors.bg,
            body: OfflineBannerColumn(
              children: [
                Expanded(
                  child: eventoAsync.when(
                    loading: () => const LoadingView(),
                    error: (e, _) => const ErrorView(
                      message: 'No se pudo cargar el evento.',
                    ),
                    data: (evento) => TwDetailScaffold(
                      eyebrow: 'Evento activo',
                      title: evento.nombre,
                      // El externo no navega hacia atrás: su cabecera es de
                      // cuenta, como el home de los internos. Cerrar sesión
                      // dejó de colgar del "atrás" y vive en el menú, donde no
                      // se pulsa por reflejo.
                      onBack: _abrirMiPerfil,
                      leading: _AvatarExterno(onTap: _abrirMiPerfil),
                      actions: [
                        TwIconButton(
                          key: const Key('externo_ajustes_button'),
                          icon: Symbols.settings_rounded,
                          iconSize: 22,
                          tooltip: 'Ajustes',
                          onTap: _mostrarMenuCuenta,
                        ),
                      ],
                      children: [
                        _EventoExternoHero(
                          evento: evento,
                          puedeCambiar: puedeCambiar,
                          onTapNombre: puedeCambiar
                              ? _mostrarSelectorEventos
                              : null,
                          onCapturarLead: () => _capturarLead(evento),
                          onEscanear: () => context.push(
                            RoutePaths.acreditarQr(widget.eventoId),
                          ),
                        ),
                        const TwSectionLabel('Resumen'),
                        _ExternoStatsCards(
                          statsAsync: statsAsync,
                          onRetry: () =>
                              ref.invalidate(externoDashboardProvider),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero del evento activo, con el mismo lenguaje que la card del home:
/// radio 22, velo sobre la foto, píldora de fecha y CTA blanco de 52.
class _EventoExternoHero extends StatelessWidget {
  const _EventoExternoHero({
    required this.evento,
    required this.puedeCambiar,
    required this.onCapturarLead,
    required this.onEscanear,
    this.onTapNombre,
  });

  final Evento evento;
  final bool puedeCambiar;
  final VoidCallback onCapturarLead;
  final VoidCallback onEscanear;
  final VoidCallback? onTapNombre;

  @override
  Widget build(BuildContext context) {
    final lugar = [
      if (evento.lugar != null && evento.lugar!.isNotEmpty) evento.lugar,
      if (evento.direccion != null && evento.direccion!.isNotEmpty)
        evento.direccion,
      if (evento.pais != null && evento.pais!.isNotEmpty) evento.pais,
    ].join(' · ');
    final imagenUrl = evento.imagenUrl;

    final nombreWidget = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            evento.nombre,
            style: TwText.heroTitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (puedeCambiar) ...[
          const SizedBox(width: 6),
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(
              Symbols.expand_more_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ],
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: TwGradients.hero,
        borderRadius: TwRadii.hero,
        boxShadow: TwShadows.hero,
      ),
      child: Stack(
        children: [
          if (imagenUrl != null && imagenUrl.isNotEmpty)
            Positioned.fill(
              child: EventoHeroFoto(imagenUrl: imagenUrl, velo: 0),
            ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: TwGradients.heroScrim),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: TwDatePill(formatearFechaLarga(evento.fecha)),
                    ),
                    const SizedBox(width: 8),
                    TwStatusPill(
                      evento.yaOcurrio ? TwStatus.finalizado : TwStatus.activo,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (onTapNombre != null)
                  TwPressable(onTap: onTapNombre, child: nombreWidget)
                else
                  nombreWidget,
                if (lugar.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Symbols.location_on_rounded,
                        size: 16,
                        color: TwColors.whiteA66,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          lugar,
                          style: TwText.heroMeta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                // La operación del externo es capturar leads, no acreditar:
                // el CTA principal es el formulario y el escáner queda como
                // atajo para prellenarlo desde el QR de un asistente.
                TwHeroButton(
                  key: const Key('externo_capturar_lead_button'),
                  label: 'Capturar lead',
                  icon: Symbols.person_add_rounded,
                  onTap: onCapturarLead,
                ),
                const SizedBox(height: 10),
                TwHeroButton(
                  key: const Key('externo_scan_qr_button'),
                  label: 'Escanear QR',
                  icon: Symbols.qr_code_scanner_rounded,
                  onTap: onEscanear,
                ),
              ],
            ),
          ),
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
                  child: TwKpiCard(
                    key: const Key('externo_stat_eventos'),
                    value: eventos,
                    label: 'Eventos con acceso',
                    icon: Symbols.calendar_month_rounded,
                    tint: TwColors.blueTint,
                    iconColor: TwColors.blueInk,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TwKpiCard(
                    key: const Key('externo_stat_leads'),
                    value: leads,
                    label: 'Leads capturados',
                    icon: Symbols.person_search_rounded,
                    tint: TwColors.greenTint,
                    iconColor: TwColors.greenInk,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (stats?.esResumenParcial == true) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Symbols.info_rounded, size: 15, color: TwColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Resumen parcial: se muestran las capturas pendientes del '
                  'dispositivo.',
                  style: TwText.tileSubtitle.copyWith(fontSize: 11.5),
                ),
              ),
            ],
          ),
        ],
        if (statsAsync.hasError) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: const BoxDecoration(
              color: TwColors.dangerTint,
              borderRadius: TwRadii.field,
            ),
            child: Row(
              children: [
                const Icon(
                  Symbols.error_rounded,
                  size: 18,
                  color: TwColors.danger,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'No pudimos actualizar tu resumen.',
                    style: TwText.errorText,
                  ),
                ),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: TwColors.brand700,
                    textStyle: TwText.linkText,
                  ),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Foto de perfil en la cabecera del externo, con el mismo gesto que en el
/// home de los internos: toca y entra a su ficha.
class _AvatarExterno extends ConsumerWidget {
  const _AvatarExterno({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fotoUrl = ref.watch(currentPerfilProvider).valueOrNull?.fotoUrl;

    return TwPressable(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: TwColors.blueTint,
        ),
        child: fotoUrl == null || fotoUrl.isEmpty
            ? const Icon(
                Symbols.person_rounded,
                size: 22,
                color: TwColors.blueInk,
              )
            : AppNetworkImage(url: fotoUrl, memCacheWidth: 132),
      ),
    );
  }
}
