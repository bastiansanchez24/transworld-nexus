import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';
import 'permissions_bootstrap.dart';
import 'tw_bottom_nav_bar.dart';

/// Shell con la navegación del rediseño: barra flotante en móvil/web y rail
/// izquierdo en Windows.
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
      child: ShellNavScope(
        child: PermissionsBootstrap(
          child: MainShellNavHost(
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
                TwNavItemData(icon: tab.icon, label: tab.label),
            ],
            body: navigationShell,
          ),
        ),
      ),
    );
  }
}

/// Coloca el menú abajo (móvil/web) o a la izquierda (Windows).
class MainShellNavHost extends StatelessWidget {
  const MainShellNavHost({
    super.key,
    required this.body,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
  });

  final Widget body;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<TwNavItemData> items;

  @override
  Widget build(BuildContext context) {
    if (GlassNavTokens.usesSideRail) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            TwSideNavRail(
              selectedIndex: selectedIndex,
              onItemSelected: onItemSelected,
              items: items,
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      extendBody: true,
      // Zona muerta: el anillo alrededor del panel absorbe los taps para
      // que no lleguen al contenido que pasa por debajo (`extendBody`).
      bottomNavigationBar: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: EdgeInsets.only(
              top: GlassNavTokens.deadZone,
              left: GlassNavTokens.horizontalMargin,
              right: GlassNavTokens.horizontalMargin,
              bottom: GlassNavTokens.floatingBottomPadding(context),
            ),
            child: TwBottomNavBar(
              selectedIndex: selectedIndex,
              onItemSelected: onItemSelected,
              items: items,
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
