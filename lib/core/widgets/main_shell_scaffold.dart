import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';
import 'ios_native_tab_bar.dart';
import 'permissions_bootstrap.dart';
import 'shell_tab_scroll.dart';
import 'tw_bottom_nav_bar.dart';

/// Shell con la navegación del rediseño: `UITabBar` nativo en iOS, barra
/// flotante en Android y web móvil, y rail izquierdo en Windows y web de PC.
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
        sfSymbol: 'house',
        sfSymbolActive: 'house.fill',
      ),
      const _TabItem(
        icon: Symbols.calendar_month_rounded,
        label: 'Eventos',
        branch: _branchEventos,
        sfSymbol: 'calendar',
        sfSymbolActive: 'calendar.fill',
      ),
      // SF Symbols de proporción cuadrada a propósito: `UITabBar` mide cada
      // ítem por su icono, así que los símbolos anchos (`person.3`,
      // `person.crop.circle.badge.magnifyingglass`) estiraban su celda y
      // dejaban la fila descompensada.
      const _TabItem(
        icon: Symbols.person_search_rounded,
        label: 'Leads',
        branch: _branchCapturador,
        sfSymbol: 'person.crop.circle',
        sfSymbolActive: 'person.crop.circle.fill',
      ),
      if (puedeGestionarUsuarios)
        const _TabItem(
          icon: Symbols.group_rounded,
          label: 'Usuarios',
          branch: _branchUsuarios,
          sfSymbol: 'person.2',
          sfSymbolActive: 'person.2.fill',
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
              final branch = tabs[index].branch;
              navigationShell.goBranch(branch, initialLocation: true);
              ref.read(shellTabEpochProvider(branch).notifier).state++;
            },
            items: [
              for (final tab in tabs)
                TwNavItemData(
                  icon: tab.icon,
                  label: tab.label,
                  sfSymbol: tab.sfSymbol,
                  sfSymbolActive: tab.sfSymbolActive,
                ),
            ],
            body: navigationShell,
          ),
        ),
      ),
    );
  }
}

/// Coloca el menú abajo (iOS nativo / Android / web móvil) o a la izquierda
/// (Windows y web de PC).
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
    if (GlassNavTokens.usesSideRailOf(context)) {
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

    if (GlassNavTokens.usesNativeIosTabBar) {
      return Scaffold(
        body: body,
        extendBody: true,
        bottomNavigationBar: IosNativeTabBar(
          currentIndex: selectedIndex,
          onTap: onItemSelected,
          items: items,
          tint: AppColors.primary,
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
    required this.sfSymbol,
    this.sfSymbolActive,
  });

  final IconData icon;
  final String label;
  final int branch;
  final String sfSymbol;
  final String? sfSymbolActive;
}
