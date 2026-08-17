import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/env.dart';
import '../../../core/router/refresh_on_visible.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/browser_theme_color.dart';
import '../../../core/theme/tw_tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/evento_hero_banner.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/tw_components.dart';
import '../../../core/widgets/tw_detail_scaffold.dart';
import '../../../core/widgets/tw_toast.dart';
import '../../../data/models/evento.dart';
import '../../auth/providers/auth_providers.dart';
import '../../eventos/providers/eventos_providers.dart';
import '../../registrados/providers/registrados_providers.dart';
import '../widgets/evento_operativo_sheets.dart';

/// Menú operativo de un evento — rediseño §8 de la guía de componentes.
///
/// Hero con métricas y CTA de escaneo, seguido de dos grupos de acciones.
/// Sin barra inferior: se llega desde la lista y se vuelve con el botón atrás.
class UsarEventoScreen extends ConsumerStatefulWidget {
  const UsarEventoScreen({super.key, required this.eventoId});

  final String eventoId;

  @override
  ConsumerState<UsarEventoScreen> createState() => _UsarEventoScreenState();
}

class _UsarEventoScreenState extends ConsumerState<UsarEventoScreen>
    with RefreshOnVisible {
  @override
  String get refreshWhenLocation => RoutePaths.usarEvento(widget.eventoId);

  /// Al volver al menú (tras registrar, editar, eliminar o acreditar) se
  /// recarga la lista para que las tarjetas no queden con los conteos viejos.
  @override
  void onBecomeVisible() {
    ref.invalidate(eventoByIdProvider(widget.eventoId));
    ref.invalidate(registradosPorEventoProvider(widget.eventoId));
  }

  Future<void> _compartir() async {
    final base = Env.appPublicBaseUrl.replaceAll(RegExp(r'/$'), '');
    final link = '$base${RoutePaths.registroPublico(widget.eventoId)}';
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    TwToast.link(context, 'Enlace del evento copiado');
  }

  @override
  Widget build(BuildContext context) {
    final eventoAsync = ref.watch(eventoByIdProvider(widget.eventoId));
    final puedeEditar = ref.watch(canCreateContentProvider);
    final puedeExportar = ref.watch(canExportDataProvider);
    final esAdmin = ref.watch(isAdminProvider);
    final resumen = ref.watch(registradosResumenProvider(widget.eventoId));

    return BrowserThemeColor(
      color: TwColors.bg,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: TwColors.bg,
          body: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: eventoAsync.when(
                  loading: () => const LoadingView(),
                  error: (e, _) =>
                      const ErrorView(message: 'No se pudo cargar el evento.'),
                  data: (evento) => TwDetailScaffold(
                    eyebrow: 'Detalle del evento',
                    title: evento.nombre,
                    onBack: () => context.pop(),
                    actions: [
                      if (puedeEditar)
                        TwIconButton(
                          icon: Symbols.edit_rounded,
                          iconSize: 19,
                          tooltip: 'Editar evento',
                          onTap: () => context.push(
                            RoutePaths.editarEvento(widget.eventoId),
                          ),
                        ),
                      TwIconButton(
                        icon: Symbols.ios_share_rounded,
                        iconSize: 20,
                        variant: TwIconButtonStyle.brand,
                        tooltip: 'Copiar enlace del evento',
                        onTap: _compartir,
                      ),
                    ],
                    children: [
                      _hero(context, evento, resumen),
                      const TwSectionLabel('Acciones del evento'),
                      TwActionTile(
                        icon: Symbols.person_add_rounded,
                        iconStyle: TwIconBoxStyle.brand,
                        title: 'Registrar asistente',
                        subtitle: 'Inscribir a alguien en el evento',
                        onTap: () =>
                            EventoOperativoSheets.mostrarOpcionesRegistrarAsistente(
                              context,
                              widget.eventoId,
                            ),
                      ),
                      const SizedBox(height: TwSpacing.tileGap),
                      TwActionTile(
                        icon: Symbols.contacts_rounded,
                        title: 'Lista de asistentes registrados',
                        subtitle: _subtituloAsistentes(resumen?.total),
                        onTap: () => context.push(
                          RoutePaths.verRegistrados(widget.eventoId),
                        ),
                      ),
                      const TwSectionLabel('Administración'),
                      if (esAdmin) ...[
                        TwActionTile(
                          icon: Symbols.groups_rounded,
                          title: 'Gestionar acceso',
                          subtitle: 'Acreditar y controlar la entrada',
                          onTap: () => context.push(
                            RoutePaths.accesoEvento(widget.eventoId),
                          ),
                        ),
                        const SizedBox(height: TwSpacing.tileGap),
                      ],
                      TwActionTile(
                        icon: Symbols.bar_chart_rounded,
                        iconStyle: TwIconBoxStyle.purpleTint,
                        title: 'KPI del evento',
                        subtitle: 'Métricas y acreditación en vivo',
                        onTap: () =>
                            context.push(RoutePaths.kpi(widget.eventoId)),
                      ),
                      if (puedeExportar) ...[
                        const SizedBox(height: TwSpacing.tileGap),
                        TwActionTile(
                          icon: Symbols.table_chart_rounded,
                          iconStyle: TwIconBoxStyle.excel,
                          excel: true,
                          badge: 'XLSX',
                          title: 'Exportar a Excel',
                          subtitle: _subtituloExcel(resumen?.total),
                          onTap: () => context.push(
                            RoutePaths.exportar(widget.eventoId),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(
    BuildContext context,
    Evento evento,
    RegistradosResumen? resumen,
  ) {
    final lugar = [
      if (evento.lugar != null && evento.lugar!.isNotEmpty) evento.lugar,
      if (evento.pais != null && evento.pais!.isNotEmpty) evento.pais,
    ].join(' · ');
    final imagenUrl = evento.imagenUrl;

    return TwHeroCard(
      dateText: formatearFechaLarga(evento.fecha),
      status: evento.yaOcurrio ? TwStatus.finalizado : TwStatus.activo,
      title: evento.nombre,
      location: lugar,
      photo: imagenUrl == null || imagenUrl.isEmpty
          ? null
          // El velo lo pinta la propia TwHeroCard (heroScrim).
          : EventoHeroFoto(imagenUrl: imagenUrl, velo: 0),
      stats: [
        TwStat(
          _valor(resumen?.acreditados),
          'Acreditados',
          valueColor: TwColors.statusActive,
        ),
        TwStat(_valor(resumen?.pendientes), 'Pendientes'),
        TwStat(_valor(resumen?.total), 'Registrados'),
      ],
      ctaLabel: 'Escanear QR',
      ctaIcon: Symbols.qr_code_scanner_rounded,
      onCta: () => context.push(RoutePaths.acreditarQr(widget.eventoId)),
    );
  }

  static String _valor(int? n) => n?.toString() ?? '—';

  static String _subtituloAsistentes(int? total) {
    if (total == null) return 'Ver el listado completo';
    return total == 1 ? '1 asistente' : '$total asistentes';
  }

  static String _subtituloExcel(int? total) {
    if (total == null) return 'Asistentes registrados';
    final filas = total == 1 ? '1 fila' : '$total filas';
    return 'Asistentes registrados · $filas';
  }
}
