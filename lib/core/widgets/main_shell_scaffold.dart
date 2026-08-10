import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';
import 'permissions_bootstrap.dart';
import 'pressable.dart';

/// Tab bar frosted con pill activo (HANDOFF §4.3).
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;

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
            color: Colors.transparent,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.94),
                    border: const Border(
                      top: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: SizedBox(
                      height: AppSpacing.shellTabBarHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          for (var i = 0; i < tabs.length; i++)
                            Expanded(
                              child: _TabButton(
                                item: tabs[i],
                                selected: i == selectedIndex,
                                onTap: () {
                                  navigationShell.goBranch(
                                    tabs[i].branch,
                                    initialLocation: tabs[i].branch ==
                                        navigationShell.currentIndex,
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
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

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _TabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.92,
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        child: SizedBox(
          height: AppSpacing.shellTabBarHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: AppMotion.toggle,
                curve: AppMotion.ease,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? AppColors.tintNavy : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Icon(
                  item.icon,
                  size: 24,
                  fill: selected ? 1.0 : 0.0,
                  color:
                      selected ? AppColors.primary : AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.1,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? AppColors.primaryDeep
                      : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
