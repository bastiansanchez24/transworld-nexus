import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/offline/sync_coordinator.dart';

class TransworldNexusApp extends ConsumerWidget {
  const TransworldNexusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantiene vivo el listener de conectividad -> sincronización offline
    // durante toda la vida de la app (ver data/offline/sync_coordinator.dart).
    ref.watch(syncCoordinatorInitializerProvider);

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Transworld Nexus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
