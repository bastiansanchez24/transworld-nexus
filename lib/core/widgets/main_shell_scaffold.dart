import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_providers.dart';

/// Contenedor con barra de navegación inferior para las secciones
/// principales de la app autenticada.
class MainShellScaffold extends ConsumerWidget {
  const MainShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _branchInicio = 0;
  static const _branchEventos = 1;
  static const _branchCapturador = 2;
  static const _branchUsuarios = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esAdmin = ref.watch(isAdminProvider);
    final branchActual = navigationShell.currentIndex;

    final destinos = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Inicio',
      ),
      const NavigationDestination(
        icon: Icon(Icons.event_outlined),
        selectedIcon: Icon(Icons.event_rounded),
        label: 'Eventos',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_search_outlined),
        selectedIcon: Icon(Icons.person_search_rounded),
        label: 'Leads',
      ),
      if (esAdmin)
        const NavigationDestination(
          icon: Icon(Icons.people_alt_outlined),
          selectedIcon: Icon(Icons.people_alt_rounded),
          label: 'Usuarios',
        ),
    ];

    final indiceVisible = branchActual > _branchCapturador && !esAdmin
        ? _branchInicio
        : branchActual.clamp(0, destinos.length - 1);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: indiceVisible,
        onDestinationSelected: (indice) {
          final branch = _branchDesdeIndice(indice, esAdmin);
          navigationShell.goBranch(
            branch,
            initialLocation: branch == navigationShell.currentIndex,
          );
        },
        destinations: destinos,
      ),
    );
  }

  int _branchDesdeIndice(int indice, bool esAdmin) {
    if (!esAdmin) {
      return switch (indice) {
        1 => _branchEventos,
        2 => _branchCapturador,
        _ => _branchInicio,
      };
    }
    return switch (indice) {
      1 => _branchEventos,
      2 => _branchCapturador,
      3 => _branchUsuarios,
      _ => _branchInicio,
    };
  }
}
