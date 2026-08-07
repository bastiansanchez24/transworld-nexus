import 'dart:io' show exit;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/nexus_components.dart';
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
import '../models/home_featured_item.dart';
import '../providers/home_dashboard_providers.dart';
import '../providers/home_featured_providers.dart';
import '../widgets/home_dashboard_section.dart';
import '../widgets/proximo_evento_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _menuCuentaAbierto = false;
  bool _desinstalando = false;

  Future<void> _desinstalar() async {
    if (_desinstalando || !canUninstallApp) return;
    setState(() => _menuCuentaAbierto = false);

    final ok = await confirmDialog(
      context,
      title: 'Desinstalar Nexus',
      message:
          'Se eliminarán la aplicación, los accesos directos y los datos '
          'locales de Nexus en este equipo. Esta acción no se puede deshacer.',
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

  @override
  Widget build(BuildContext context) {
    final perfilAsync = ref.watch(currentPerfilProvider);
    final perfil = perfilAsync.valueOrNull;
    final featuredItems =
        ref.watch(homeFeaturedItemsProvider).valueOrNull ?? const [];
    final noLeidas = ref.watch(notificacionesNoLeidasProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: UpdateChecker(
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              const OfflineBanner(),
              _HeaderPerfil(
                perfil: perfil,
                menuAbierto: _menuCuentaAbierto,
                featuredItems: featuredItems,
                noLeidas: noLeidas,
                onNotificaciones: () => context.push(RoutePaths.notificaciones),
                onToggleMenu: () =>
                    setState(() => _menuCuentaAbierto = !_menuCuentaAbierto),
                onMiPerfil: () {
                  setState(() => _menuCuentaAbierto = false);
                  context.push(RoutePaths.perfil);
                },
                onActualizaciones: () {
                  setState(() => _menuCuentaAbierto = false);
                  context.push(RoutePaths.actualizaciones);
                },
                onDesinstalar: canUninstallApp ? _desinstalar : null,
                onCerrarSesion: () =>
                    ref.read(authRepositoryProvider).cerrarSesion(),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
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
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: perfilAsync.when(
                            loading: () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 48),
                              child: LoadingView(),
                            ),
                            error: (e, _) => ErrorView(
                              message: 'No se pudo cargar tu perfil.',
                              onRetry: () =>
                                  ref.invalidate(currentPerfilProvider),
                            ),
                            data: (_) => const HomeDashboardSection(),
                          ),
                        ),
                      ),
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
}

class _HeaderPerfil extends StatelessWidget {
  const _HeaderPerfil({
    required this.perfil,
    required this.menuAbierto,
    required this.featuredItems,
    required this.noLeidas,
    required this.onNotificaciones,
    required this.onToggleMenu,
    required this.onMiPerfil,
    required this.onActualizaciones,
    this.onDesinstalar,
    required this.onCerrarSesion,
  });

  final Perfil? perfil;
  final bool menuAbierto;
  final List<HomeFeaturedItem> featuredItems;
  final int noLeidas;
  final VoidCallback onNotificaciones;
  final VoidCallback onToggleMenu;
  final VoidCallback onMiPerfil;
  final VoidCallback onActualizaciones;
  final VoidCallback? onDesinstalar;
  final VoidCallback onCerrarSesion;

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
    final topPad = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.header),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topPad + 8, 20, 22),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Pressable(
                      scale: 0.94,
                      onTap: onMiPerfil,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: AvatarPerfil(
                          nombre: perfil?.nombreCompleto ?? '?',
                          fotoUrl: perfil?.fotoUrl,
                          size: 44,
                          index: 0,
                        ),
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
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (rol.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            _HeaderRoleChip(label: rol),
                          ],
                        ],
                      ),
                    ),
                    NotificacionesHeaderButton(
                      noLeidas: noLeidas,
                      onTap: onNotificaciones,
                    ),
                    const SizedBox(width: 8),
                    Pressable(
                      scale: 0.92,
                      onTap: onToggleMenu,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          menuAbierto
                              ? Symbols.close_rounded
                              : Symbols.settings_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                if (featuredItems.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ProximoEventoCard(items: featuredItems),
                ],
                AnimatedSize(
                  duration: AppMotion.toggle,
                  curve: AppMotion.ease,
                  alignment: Alignment.topCenter,
                  child: menuAbierto
                      ? Padding(
                          padding: EdgeInsets.only(
                            top: featuredItems.isNotEmpty ? 12 : 16,
                          ),
                          child: _MenuCuenta(
                            onMiPerfil: onMiPerfil,
                            onActualizaciones: onActualizaciones,
                            onDesinstalar: onDesinstalar,
                            onCerrarSesion: onCerrarSesion,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
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
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
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
            icon: Symbols.system_update_rounded,
            label: 'Actualizaciones',
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
