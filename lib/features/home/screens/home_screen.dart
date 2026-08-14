import 'dart:io' show exit;
import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/browser_theme_color.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/collapsing_nav.dart';
import '../../../core/widgets/notificaciones_header_button.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/perfil.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../fijados/providers/fijados_providers.dart';
import '../../notificaciones/providers/notificaciones_providers.dart';
import '../../updates/services/update_platform.dart';
import '../../updates/services/windows_uninstaller.dart';
import '../../updates/widgets/update_checker.dart';
import '../providers/home_dashboard_providers.dart';
import '../providers/home_featured_providers.dart';
import '../widgets/home_dashboard_section.dart';
import '../widgets/proximo_evento_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _menuCuentaAbierto = false;
  bool _desinstalando = false;
  final _scrollTop = ValueNotifier<double>(0);
  late final AnimationController _enterCtrl;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(vsync: this, duration: AppMotion.screenIn)
      ..forward();
  }

  @override
  void dispose() {
    _scrollTop.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  Future<void> _desinstalar() async {
    if (_desinstalando || !canUninstallApp) return;
    setState(() => _menuCuentaAbierto = false);

    final ok = await confirmDialog(
      context,
      title: 'Desinstalar RegisPro',
      message:
          'Se eliminarán la aplicación, los accesos directos y los datos '
          'locales de RegisPro en este equipo. Esta acción no se puede deshacer.',
      confirmLabel: 'Desinstalar',
      destructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _desinstalando = true);
    final result = await WindowsUninstaller().uninstall();
    if (!mounted) return;

    if (result.outcome == WindowsUninstallOutcome.launched) {
      Future.delayed(const Duration(milliseconds: 800), () => exit(0));
      return;
    }

    setState(() => _desinstalando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message ?? 'No se pudo iniciar la desinstalación.',
        ),
      ),
    );
  }

  String _firstName(Perfil? perfil) {
    final nombre = perfil?.nombreCompleto.trim() ?? '';
    if (nombre.isEmpty) return '';
    return nombre.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final perfilAsync = ref.watch(currentPerfilProvider);
    final perfil = perfilAsync.valueOrNull;
    final featuredItems =
        ref.watch(homeFeaturedItemsProvider).valueOrNull ?? const [];
    final noLeidas = ref.watch(notificacionesNoLeidasProvider);
    final first = _firstName(perfil);
    final saludo = first.isEmpty ? 'Hola 👋' : 'Hola, $first 👋';
    final reduce = AppMotion.reduceMotion(context);
    final safeTop = MediaQuery.paddingOf(context).top;
    // Sin barra de estado (web y Windows) no hay nada que despejar arriba: el
    // aire fijo del spec dejaba la identidad hundida media pantalla.
    final contentTop = safeTop + _HomeHeaderMetrics.topGap(safeTop);
    // El avatar parte a [contentTop]; el blur espera a que toque el safe area.
    final collapseStart = contentTop - safeTop;
    final bottomPad = math.max(
      120.0,
      GlassNavTokens.contentBottomInset(context),
    );

    final body = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;
        _scrollTop.value = notification.metrics.pixels;
        return false;
      },
      child: RefreshIndicator(
        color: AppColors.primary,
        displacement: safeTop + 72,
        onRefresh: () async {
          ref.invalidate(homeDashboardProvider);
          ref.invalidate(homeFeaturedItemsProvider);
          ref.invalidate(eventosFijadosProvider);
          ref.invalidate(campanasFijadasProvider);
          ref.invalidate(currentPerfilProvider);
        },
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(0, contentTop, 0, bottomPad),
          children: [
            _HomeColumn(
              child: _HeaderPerfil(
                perfil: perfil,
                menuAbierto: _menuCuentaAbierto,
                noLeidas: noLeidas,
                onNotificaciones: () => context.push(RoutePaths.notificaciones),
                onToggleMenu: () =>
                    setState(() => _menuCuentaAbierto = !_menuCuentaAbierto),
                onMiPerfil: () {
                  setState(() => _menuCuentaAbierto = false);
                  context.push(RoutePaths.perfil);
                },
              ),
            ),
            if (featuredItems.isNotEmpty) ...[
              const SizedBox(height: 18),
              ProximoEventoCard(items: featuredItems),
            ],
            _HomeColumn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedSize(
                    duration: AppMotion.toggle,
                    curve: AppMotion.ease,
                    alignment: Alignment.topCenter,
                    child: _menuCuentaAbierto
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _MenuCuenta(
                              onMiPerfil: () {
                                setState(() => _menuCuentaAbierto = false);
                                context.push(RoutePaths.perfil);
                              },
                              onActualizaciones: () {
                                setState(() => _menuCuentaAbierto = false);
                                context.push(RoutePaths.actualizaciones);
                              },
                              onDesinstalar: canUninstallApp
                                  ? _desinstalar
                                  : null,
                              onCerrarSesion: () => ref
                                  .read(authRepositoryProvider)
                                  .cerrarSesion(),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),
                  perfilAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: LoadingView(),
                    ),
                    error: (e, _) => ErrorView(
                      message: 'No se pudo cargar tu perfil.',
                      onRetry: () => ref.invalidate(currentPerfilProvider),
                    ),
                    data: (_) => const HomeDashboardSection(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final enter = reduce
        ? body
        : FadeTransition(
            opacity: CurvedAnimation(parent: _enterCtrl, curve: AppMotion.ease),
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.024),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: _enterCtrl, curve: AppMotion.ease),
                  ),
              child: body,
            ),
          );

    return BrowserThemeColor(
      color: AppColors.background,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: UpdateChecker(
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: Column(
              children: [
                const OfflineBanner(),
                Expanded(
                  child: Stack(
                    children: [
                      enter,
                      ValueListenableBuilder<double>(
                        valueListenable: _scrollTop,
                        builder: (context, t, _) {
                          return _HomeCollapseBar(
                            scrollTop: t,
                            title: saludo,
                            collapseStart: collapseStart,
                          );
                        },
                      ),
                    ],
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

/// Columna del home con el gutter de pantalla. El carrusel de eventos se
/// sale de este wrapper para poder deslizar hasta el borde.
class _HomeColumn extends StatelessWidget {
  const _HomeColumn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.contentMax),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}

/// Medidas del header de identidad: el avatar vive a [topGap] bajo el safe area.
abstract final class _HomeHeaderMetrics {
  static const avatarSize = 44.0;
  static const topGapWithSafeArea = 12.0;
  static const topGapWithoutSafeArea = 16.0;

  static double topGap(double safeTop) =>
      safeTop > 0 ? topGapWithSafeArea : topGapWithoutSafeArea;
}

class _HomeCollapseBar extends StatelessWidget {
  const _HomeCollapseBar({
    required this.scrollTop,
    required this.title,
    required this.collapseStart,
  });

  final double scrollTop;
  final String title;

  /// Scroll en el que el avatar toca el borde superior (bajo el safe area).
  final double collapseStart;

  static List<double> _saturationMatrix(double s) {
    const r = 0.213;
    const g = 0.715;
    const b = 0.072;
    final inv = 1 - s;
    return [
      inv * r + s,
      inv * g,
      inv * b,
      0,
      0,
      inv * r,
      inv * g + s,
      inv * b,
      0,
      0,
      inv * r,
      inv * g,
      inv * b + s,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final barHeight = safeTop + 52;
    final start = collapseStart < 0 ? 0.0 : collapseStart;
    final opacity =
        ((scrollTop - start) / CollapsingNavMetrics.collapseFadeRange).clamp(
          0.0,
          1.0,
        );
    final titleOpacity = opacity;
    final titleTranslateY = (1 - titleOpacity) * 6;
    final visible = opacity > 0.01;

    return IgnorePointer(
      ignoring: opacity < 0.45,
      child: SizedBox(
        height: barHeight,
        child: Stack(
          children: [
            if (visible)
              Positioned.fill(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.compose(
                      inner: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      outer: ColorFilter.matrix(_saturationMatrix(1.8)),
                    ),
                    child: ColoredBox(
                      color: Color.fromRGBO(242, 245, 249, 0.72 * opacity),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: safeTop,
              left: 20,
              right: 20,
              bottom: 0,
              child: Opacity(
                opacity: titleOpacity,
                child: Transform.translate(
                  offset: Offset(0, titleTranslateY),
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppColors.identityInk,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderPerfil extends StatelessWidget {
  const _HeaderPerfil({
    required this.perfil,
    required this.menuAbierto,
    required this.noLeidas,
    required this.onNotificaciones,
    required this.onToggleMenu,
    required this.onMiPerfil,
  });

  final Perfil? perfil;
  final bool menuAbierto;
  final int noLeidas;
  final VoidCallback onNotificaciones;
  final VoidCallback onToggleMenu;
  final VoidCallback onMiPerfil;

  String get _firstName {
    final nombre = perfil?.nombreCompleto.trim() ?? '';
    if (nombre.isEmpty) return '';
    return nombre.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final first = _firstName;
    final saludo = first.isEmpty ? 'Hola 👋' : 'Hola, $first 👋';
    final rol = perfil?.rol.label ?? '';

    return Row(
      children: [
        Pressable(
          scale: 0.94,
          onTap: onMiPerfil,
          child: _HomeAvatar(
            nombre: perfil?.nombreCompleto ?? '?',
            fotoUrl: perfil?.fotoUrl,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                saludo,
                style: const TextStyle(
                  color: AppColors.identityInk,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  height: 1.15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (rol.isNotEmpty) ...[
                const SizedBox(height: 4),
                _HeaderRoleChip(label: rol),
              ],
            ],
          ),
        ),
        _IconChip(
          icon: menuAbierto ? Symbols.close_rounded : Symbols.settings_rounded,
          onTap: onToggleMenu,
        ),
        const SizedBox(width: 8),
        NotificacionesHeaderButton(noLeidas: noLeidas, onTap: onNotificaciones),
      ],
    );
  }
}

class _HomeAvatar extends StatelessWidget {
  const _HomeAvatar({required this.nombre, this.fotoUrl});

  final String nombre;
  final String? fotoUrl;

  String get _inicial {
    final trimmed = nombre.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final tieneFoto = fotoUrl != null && fotoUrl!.isNotEmpty;
    return Container(
      width: _HomeHeaderMetrics.avatarSize,
      height: _HomeHeaderMetrics.avatarSize,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: tieneFoto
            ? CachedNetworkImage(
                imageUrl: fotoUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 132,
                placeholder: (_, _) => _Inicial(letra: _inicial),
                errorWidget: (_, _, _) => _Inicial(letra: _inicial),
              )
            : _Inicial(letra: _inicial),
      ),
    );
  }
}

class _Inicial extends StatelessWidget {
  const _Inicial({required this.letra});

  final String letra;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        letra,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppColors.heroNavy,
          height: 1,
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.92,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: AppColors.identityAccent, size: 20),
      ),
    );
  }
}

class _HeaderRoleChip extends StatelessWidget {
  const _HeaderRoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.identityChip,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.identityAccent,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _MenuCuenta extends StatelessWidget {
  const _MenuCuenta({
    required this.onMiPerfil,
    required this.onActualizaciones,
    this.onDesinstalar,
    required this.onCerrarSesion,
  });

  final VoidCallback onMiPerfil;
  final VoidCallback onActualizaciones;
  final VoidCallback? onDesinstalar;
  final VoidCallback onCerrarSesion;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppColors.shadowLifted,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _CuentaTile(
            icon: Symbols.person_rounded,
            label: 'Mi perfil',
            onTap: onMiPerfil,
          ),
          const Divider(height: 1, indent: 56, color: AppColors.divider),
          _CuentaTile(
            icon: kIsWeb
                ? Symbols.history_rounded
                : Symbols.system_update_rounded,
            label: kIsWeb ? 'Historial de versiones' : 'Actualizaciones',
            onTap: onActualizaciones,
          ),
          if (onDesinstalar != null) ...[
            const Divider(height: 1, indent: 56, color: AppColors.divider),
            _CuentaTile(
              icon: Symbols.delete_forever_rounded,
              label: 'Desinstalar',
              destructivo: true,
              onTap: onDesinstalar!,
            ),
          ],
          const Divider(height: 1, indent: 56, color: AppColors.divider),
          _CuentaTile(
            icon: Symbols.logout_rounded,
            label: 'Cerrar sesión',
            destructivo: true,
            onTap: onCerrarSesion,
          ),
        ],
      ),
    );
  }
}

class _CuentaTile extends StatelessWidget {
  const _CuentaTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructivo = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructivo;

  @override
  Widget build(BuildContext context) {
    final color = destructivo ? AppColors.danger : AppColors.ink;
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            if (!destructivo)
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
