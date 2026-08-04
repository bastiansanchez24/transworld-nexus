import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../data/repositories/notificaciones_repository.dart';
import '../../../firebase_options.dart';
import '../../auth/providers/auth_providers.dart';

const _androidChannelId = 'nexus_registros';
const _androidChannelName = 'Registros de eventos';

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final service = PushNotificationService(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// Arranca FCM y mantiene el token sincronizado con Supabase.
final pushNotificationsBootstrapProvider = Provider<void>((ref) {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;

  final service = ref.watch(pushNotificationServiceProvider);

  ref.listen(authStateChangesProvider, (_, next) async {
    final session = next.valueOrNull?.session;
    if (session == null) {
      await service.onLogout();
      return;
    }
    await service.syncToken();
  });

  final sesionInicial = ref.read(authStateChangesProvider).valueOrNull?.session;
  if (sesionInicial != null) {
    Future.microtask(service.syncToken);
  }
});

class PushNotificationService {
  PushNotificationService(this._ref);

  final Ref _ref;

  final _localNotifications = FlutterLocalNotificationsPlugin();
  GoRouter? _router;
  String? _tokenActual;
  bool _inicializado = false;
  StreamSubscription<String>? _tokenRefreshSub;

  void attachRouter(GoRouter router) => _router = router;

  Future<void> initialize() async {
    if (_inicializado || kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return;
    }
    if (!DefaultFirebaseOptions.isConfigured) {
      debugPrint('Push: firebase_options sin configurar; solo inbox in-app.');
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      await _configurarCanalAndroid();
      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (_) => _abrirInbox(),
      );

      FirebaseMessaging.onMessage.listen(_mostrarForeground);
      FirebaseMessaging.onMessageOpenedApp.listen((_) => _abrirInbox());

      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        Future.microtask(_abrirInbox);
      }

      _inicializado = true;
    } catch (e, st) {
      debugPrint('Push init falló: $e\n$st');
    }
  }

  /// Registra o actualiza el token FCM tras autenticarse.
  /// El permiso de notificaciones lo pide [AppPermissions] en el bootstrap.
  Future<void> syncToken() async {
    await initialize();
    if (!_inicializado) return;

    try {
      final messaging = FirebaseMessaging.instance;

      if (Platform.isIOS) {
        final apns = await messaging.getAPNSToken();
        if (apns == null) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;

      _tokenActual = token;
      final plataforma = Platform.isIOS ? 'ios' : 'android';
      await _ref.read(notificacionesRepositoryProvider).guardarDeviceToken(
            token: token,
            plataforma: plataforma,
          );

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = messaging.onTokenRefresh.listen((nuevo) async {
        if (_tokenActual != null && _tokenActual != nuevo) {
          await _ref
              .read(notificacionesRepositoryProvider)
              .eliminarDeviceToken(_tokenActual!);
        }
        _tokenActual = nuevo;
        await _ref.read(notificacionesRepositoryProvider).guardarDeviceToken(
              token: nuevo,
              plataforma: plataforma,
            );
      });
    } catch (e) {
      debugPrint('Push syncToken falló: $e');
    }
  }

  Future<void> onLogout() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    if (_tokenActual != null) {
      try {
        await _ref
            .read(notificacionesRepositoryProvider)
            .eliminarDeviceToken(_tokenActual!);
      } catch (_) {}
      _tokenActual = null;
    }
  }

  void dispose() {
    unawaited(_tokenRefreshSub?.cancel());
    _tokenRefreshSub = null;
  }

  Future<void> _configurarCanalAndroid() async {
    if (!Platform.isAndroid) return;
    const channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: 'Avisos cuando alguien se registra a un evento.',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _mostrarForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
    );
  }

  void _abrirInbox() {
    _router?.push(RoutePaths.notificaciones);
  }
}
