import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../data/models/evento.dart';
import '../../../data/models/perfil.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/home_dashboard_providers.dart';
import '../widgets/home_dashboard_section.dart';
import '../widgets/proximo_evento_card.dart';

/// Home rediseñado al estilo iOS: el perfil del usuario vive integrado en
/// un encabezado a sangre completa (llega hasta el borde superior de la
/// pantalla, sin AppBar), y las acciones de cuenta (Mi perfil,
/// Configuraciones, Cerrar sesión) se despliegan en un panel colapsable.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _menuCuentaAbierto = false;

  @override
  Widget build(BuildContext context) {
    final perfilAsync = ref.watch(currentPerfilProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // El encabezado degradado llega hasta arriba → iconos claros.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Column(
          children: [
            _HeaderPerfil(
              perfil: perfilAsync.valueOrNull,
              menuAbierto: _menuCuentaAbierto,
              proximoEvento: ref.watch(homeDashboardProvider).valueOrNull?.proximoEvento,
              onToggleMenu: () => setState(
                  () => _menuCuentaAbierto = !_menuCuentaAbierto),
              onCerrarSesion: () =>
                  ref.read(authRepositoryProvider).cerrarSesion(),
            ),
            const OfflineBanner(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: perfilAsync.when(
                    loading: () => const LoadingView(),
                    error: (e, _) => ErrorView(
                      message: 'No se pudo cargar tu perfil.',
                      onRetry: () => ref.invalidate(currentPerfilProvider),
                    ),
                    data: (perfil) => _buildContenido(perfil),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContenido(Perfil? perfil) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(homeDashboardProvider),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.screen,
        children: [
          const HomeDashboardSection(),
        ],
      ),
    );
  }
}

/// Encabezado a sangre completa: degradado de marca que se funde con el
/// borde superior de la pantalla (el avatar y el saludo forman parte del
/// fondo, no de una tarjeta flotante).
class _HeaderPerfil extends StatelessWidget {
  const _HeaderPerfil({
    required this.perfil,
    required this.menuAbierto,
    required this.proximoEvento,
    required this.onToggleMenu,
    required this.onCerrarSesion,
  });

  final Perfil? perfil;
  final bool menuAbierto;
  final Evento? proximoEvento;
  final VoidCallback onToggleMenu;
  final VoidCallback onCerrarSesion;

  @override
  Widget build(BuildContext context) {
    final nombre = perfil?.nombreCompleto ?? '';
    final rol = perfil?.rol.label ?? '';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        child: Text(
                          nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre.isEmpty ? 'Hola' : 'Hola, $nombre',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (rol.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(
                                  rol,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Semantics(
                        label: 'Opciones de cuenta',
                        expanded: menuAbierto,
                        button: true,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: onToggleMenu,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: AnimatedRotation(
                                turns: menuAbierto ? 0.5 : 0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                child: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (proximoEvento != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: ProximoEventoCard(evento: proximoEvento!),
                  ),
                ),
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: menuAbierto
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        proximoEvento != null ? AppSpacing.md : 0,
                        20,
                        20,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: _MenuCuenta(onCerrarSesion: onCerrarSesion),
                        ),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: proximoEvento != null ? AppSpacing.lg : 0,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista agrupada estilo iOS con las opciones de cuenta.
class _MenuCuenta extends StatelessWidget {
  const _MenuCuenta({required this.onCerrarSesion});

  final VoidCallback onCerrarSesion;

  @override
  Widget build(BuildContext context) {
    void proximamente() =>
        showAppSnackBar(context, 'Disponible próximamente.');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _CuentaTile(
            icon: Icons.person_outline_rounded,
            label: 'Mi perfil',
            onTap: proximamente,
          ),
          const Divider(height: 1, indent: 56),
          _CuentaTile(
            icon: Icons.settings_outlined,
            label: 'Configuraciones',
            onTap: proximamente,
          ),
          const Divider(height: 1, indent: 56),
          _CuentaTile(
            icon: Icons.logout_rounded,
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
    final color = destructivo ? AppColors.error : AppColors.primaryDark;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
      trailing: destructivo
          ? null
          : const Icon(Icons.chevron_right_rounded,
              color: AppColors.textSecondary),
    );
  }
}
