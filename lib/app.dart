import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_bootstrap.dart';
import 'core/desktop/desktop_window.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/browser_theme_color.dart';
import 'core/widgets/app_widgets.dart';
import 'core/widgets/sync_conflict_listener.dart';
import 'data/offline/sync_coordinator.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/notificaciones/providers/notificaciones_providers.dart';
import 'features/notificaciones/services/push_notification_service.dart';

class TransworldNexusApp extends ConsumerWidget {
  const TransworldNexusApp({super.key});

  static String get publicAppName =>
      kIsWeb ? 'Transworld | RegisPro' : 'RegisPro';

  static const _localizationsDelegates = [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boot = ref.watch(appBootstrapProvider);

    if (boot.hasValue) {
      ref.watch(currentPerfilProvider);
      return const _ReadyApp();
    }

    return BrowserThemeColor(
      color: AppColors.background,
      child: MaterialApp(
        title: publicAppName,
        debugShowCheckedModeBanner: false,
        // Tema liviano: [AppTheme.light] baja Plus Jakarta (google_fonts) y
        // retrasaría el primer frame que Android usa para soltar el splash.
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            surface: AppColors.background,
          ),
          scaffoldBackgroundColor: AppColors.background,
        ),
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: _localizationsDelegates,
        home: boot.hasError
            ? Scaffold(
                backgroundColor: AppColors.background,
                body: ErrorView(
                  message: 'No se pudo iniciar la app.\n${boot.error}',
                  onRetry: () => ref.invalidate(appBootstrapProvider),
                ),
              )
            : const SplashScreen(),
      ),
    );
  }
}

class _ReadyApp extends ConsumerWidget {
  const _ReadyApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantiene vivo el listener de conectividad -> sincronización offline
    // durante toda la vida de la app (ver data/offline/sync_coordinator.dart).
    ref.watch(syncCoordinatorInitializerProvider);
    ref.watch(notificacionesRealtimeSubscriptionProvider);
    ref.watch(pushNotificationsBootstrapProvider);

    final router = ref.watch(appRouterProvider);
    ref.read(pushNotificationServiceProvider).attachRouter(router);

    return BrowserThemeColor(
      color: AppColors.background,
      child: MaterialApp.router(
        title: TransworldNexusApp.publicAppName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: TransworldNexusApp._localizationsDelegates,
        routerConfig: router,
        builder: (context, child) => DesktopWindowFrame(
          child: SyncConflictListener(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
