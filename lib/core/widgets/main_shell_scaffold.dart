import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';
import 'glass_bottom_nav_bar.dart';
import 'permissions_bootstrap.dart';

/// Shell con bottom navbar Liquid Glass flotante.
///
/// Un único [PopScope] en el shell (no por rama) evita que el diálogo de
/// salida deje de aparecer tras cambiar de tab o volver de rutas hijas.
class MainShellScaffold extends ConsumerWidget {
  const MainShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _branchInicio = 0;
  static const _branchEventos = 1;
  static const _branchCapturador = 2;
  static const _branchUsuarios = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puedeGestionarUsuarios = ref.watch(canManageUsersProvider);
    final branchActual = navigationShell.currentIndex;

    final tabs = <_TabItem>[
      const _TabItem(
        icon: Symbols.home_rounded,
        label: 'Inicio',
        branch: _branchInicio,
      ),
      const _TabItem(
        icon: Symbols.calendar_month_rounded,
        label: 'Eventos',
        branch: _branchEventos,
      ),
      const _TabItem(
        icon: Symbols.person_search_rounded,
        label: 'Leads',
        branch: _branchCapturador,
      ),
      if (puedeGestionarUsuarios)
        const _TabItem(
          icon: Symbols.group_rounded,
          label: 'Usuarios',
          branch: _branchUsuarios,
        ),
    ];

    final selectedVisual = tabs.indexWhere((t) => t.branch == branchActual);
    final selectedIndex = selectedVisual < 0 ? 0 : selectedVisual;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final salir = await confirmDialog(
          context,
          title: 'Salir de la aplicación',
          message: '¿Deseas cerrar RegisPro?',
          confirmLabel: 'Salir',
        );
        if (salir && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: PermissionsBootstrap(
        child: Scaffold(
          body: navigationShell,
          extendBody: true,
          bottomNavigationBar: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: EdgeInsets.only(
                left: GlassNavTokens.horizontalMargin,
                right: GlassNavTokens.horizontalMargin,
                bottom: GlassNavTokens.floatingBottomPadding(context),
              ),
              child: GlassBottomNavBar(
                selectedIndex: selectedIndex,
                onItemSelected: (index) {
                  navigationShell.goBranch(
                    tabs[index].branch,
                    initialLocation:
                        tabs[index].branch == navigationShell.currentIndex,
                  );
                },
                items: [
                  for (final tab in tabs)
                    GlassNavItemData(icon: tab.icon, label: tab.label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.branch,
  });

  final IconData icon;
  final String label;
  final int branch;
}
