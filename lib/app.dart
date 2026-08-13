import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/sync_conflict_listener.dart';
import 'data/offline/sync_coordinator.dart';
import 'features/notificaciones/providers/notificaciones_providers.dart';
import 'features/notificaciones/services/push_notification_service.dart';

class TransworldNexusApp extends ConsumerWidget {
  const TransworldNexusApp({super.key});

  static String get publicAppName =>
      kIsWeb ? 'Transworld | RegisPro' : 'RegisPro';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantiene vivo el listener de conectividad -> sincronización offline
    // durante toda la vida de la app (ver data/offline/sync_coordinator.dart).
    ref.watch(syncCoordinatorInitializerProvider);
    ref.watch(notificacionesRealtimeSubscriptionProvider);
    ref.watch(pushNotificationsBootstrapProvider);

    final router = ref.watch(appRouterProvider);
    ref.read(pushNotificationServiceProvider).attachRouter(router);

    return MaterialApp.router(
      title: publicAppName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) =>
          SyncConflictListener(child: child ?? const SizedBox.shrink()),
    );
  }
}
