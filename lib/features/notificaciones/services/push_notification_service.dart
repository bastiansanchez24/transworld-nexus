import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/router/refresh_on_visible.dart';
import '../../../data/repositories/notificaciones_repository.dart';
import '../../../firebase_options.dart';
import '../../auth/providers/auth_providers.dart';
import '../notificacion_destino.dart';

const _androidChannelId = 'nexus_registros';
const _androidChannelName = 'Registros de eventos';

/// Push del sistema (bandeja) solo en Android. iOS queda fuera: el equipo
/// personal de Apple no firma Push Notifications, y el inbox in-app no lo
/// necesita.
bool get _fcmDelSistema => !kIsWeb && Platform.isAndroid;

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  final service = PushNotificationService(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// Arranca FCM y mantiene el token sincronizado con Supabase.
final pushNotificationsBootstrapProvider = Provider<void>((ref) {
  if (!_fcmDelSistema) return;

  final service = ref.watch(pushNotificationServiceProvider);

  ref.listen(authStateChangesProvider, (_, next) async {
    final session = next.valueOrNull?.session;
    if (session == null) {
      await service.onLogout();
      return;
    }
    await service.syncToken();
  });

  ref.listen(currentPerfilProvider, (_, next) async {
    final perfil = next.valueOrNull;
    if (perfil == null) return;
    if (perfil.canAccessNotifications) {
      await service.syncToken();
    } else {
      await service.disableNotifications();
    }
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
  Future<void>? _inicializando;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;
  String? _destinoPendiente;

  void attachRouter(GoRouter router) => _router = router;

  Future<void> initialize() {
    if (_inicializado || !_fcmDelSistema) {
      return Future<void>.value();
    }
    final enCurso = _inicializando;
    if (enCurso != null) return enCurso;

    late final Future<void> future;
    future = _initialize().whenComplete(() {
      if (identical(_inicializando, future)) _inicializando = null;
    });
    _inicializando = future;
    return future;
  }

  Future<void> _initialize() async {
    if (_inicializado || !_fcmDelSistema) return;
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
          android: AndroidInitializationSettings('@drawable/ic_notification'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (respuesta) =>
            _abrirDestino(_datosDePayload(respuesta.payload)),
      );

      _foregroundSub ??= FirebaseMessaging.onMessage.listen(_mostrarForeground);
      _messageOpenedSub ??= FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _abrirDestino(message.data),
      );

      final initial = await FirebaseMessaging.instance.getInitialMessage();
      _inicializado = true;
      if (initial != null) {
        Future.microtask(() => _abrirDestino(initial.data));
      }
    } catch (e, st) {
      debugPrint('Push init falló: $e\n$st');
    }
  }

  /// Registra o actualiza el token FCM tras autenticarse.
  /// El permiso de notificaciones lo pide [AppPermissions] en el bootstrap.
  Future<void> syncToken() async {
    // El perfil llega después de auth; esperar su resolución evita registrar
    // tokens durante esa ventana para un usuario externo.
    try {
      final perfil = await _ref.read(currentPerfilProvider.future);
      if (perfil == null || !perfil.canAccessNotifications) {
        await disableNotifications();
        return;
      }
    } catch (_) {
      return; // fail closed si el perfil no pudo verificarse
    }

    await initialize();
    if (!_inicializado) return;

    try {
      final messaging = FirebaseMessaging.instance;

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;

      _tokenActual = token;
      const plataforma = 'android';
      await _ref
          .read(notificacionesRepositoryProvider)
          .guardarDeviceToken(token: token, plataforma: plataforma);

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = messaging.onTokenRefresh.listen((nuevo) async {
        final perfil = _ref.read(currentPerfilProvider).valueOrNull;
        if (perfil?.canAccessNotifications != true) {
          await disableNotifications();
          return;
        }
        if (_tokenActual != null && _tokenActual != nuevo) {
          await _ref
              .read(notificacionesRepositoryProvider)
              .eliminarDeviceToken(_tokenActual!);
        }
        _tokenActual = nuevo;
        await _ref
            .read(notificacionesRepositoryProvider)
            .guardarDeviceToken(token: nuevo, plataforma: plataforma);
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

  /// Retira tokens persistidos y listeners cuando el rol no tiene acceso.
  Future<void> disableNotifications() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _tokenActual = null;
    try {
      await _ref
          .read(notificacionesRepositoryProvider)
          .eliminarTokensDelUsuario();
    } catch (_) {}
  }

  void dispose() {
    unawaited(_tokenRefreshSub?.cancel());
    unawaited(_foregroundSub?.cancel());
    unawaited(_messageOpenedSub?.cancel());
    _tokenRefreshSub = null;
    _foregroundSub = null;
    _messageOpenedSub = null;
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
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  Future<void> _mostrarForeground(RemoteMessage message) async {
    final perfil = _ref.read(currentPerfilProvider).valueOrNull;
    if (perfil?.canAccessNotifications != true) return;

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
      // El `data` viaja en el payload para que tocar el aviso en primer plano
      // lleve al mismo sitio que tocarlo desde la bandeja.
      payload: jsonEncode(message.data),
    );
  }

  /// Navega a lo que la notificación referencia; si no apunta a nada abrible,
  /// al inbox.
  void _abrirDestino(Map<String, dynamic> data) {
    final perfil = _ref.read(currentPerfilProvider).valueOrNull;
    if (perfil?.canAccessNotifications != true) return;
    final router = _router;
    if (router == null) return;
    final destino = destinoDeDatosPush(data) ?? RoutePaths.notificaciones;
    final actual = locationOfRouter(router);
    if (!debeApilarDestinoNotificacion(
      ubicacionActual: actual,
      destino: destino,
      destinoPendiente: _destinoPendiente,
    )) {
      return;
    }

    // Dos inicializaciones simultáneas de FCM podían entregar el mismo toque a
    // dos listeners antes de que GoRouter alcanzara a actualizar su ubicación.
    _destinoPendiente = destino;
    router.push(destino);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_destinoPendiente == destino) _destinoPendiente = null;
    });
  }

  Map<String, dynamic> _datosDePayload(String? payload) {
    if (payload == null || payload.isEmpty) return const {};
    try {
      final decodificado = jsonDecode(payload);
      return decodificado is Map<String, dynamic> ? decodificado : const {};
    } catch (_) {
      return const {};
    }
  }
}
