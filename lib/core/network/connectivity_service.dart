import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `connectivity_plus` informa disponibilidad de interfaz, no acceso real a
/// Internet. Esta comprobación permite convertir fallos de transporte en una
/// escritura offline sin ocultar errores de validación, permisos o RLS.
bool isNetworkTransportError(Object error) {
  final type = error.runtimeType.toString().toLowerCase();
  final message = error.toString().toLowerCase();
  return type.contains('socketexception') ||
      type.contains('clientexception') ||
      type.contains('timeoutexception') ||
      message.contains('socketexception') ||
      message.contains('failed host lookup') ||
      message.contains('network is unreachable') ||
      message.contains('connection refused') ||
      message.contains('connection reset') ||
      message.contains('connection closed') ||
      message.contains('timed out') ||
      message.contains('timeout') ||
      message.contains('xmlhttprequest error') ||
      message.contains('failed to fetch');
}

/// Único punto de verdad sobre el estado de conexión.
///
/// El proyecto legado tenía la detección de red repetida y ligeramente
/// distinta en cada pantalla (`NetInfo.addEventListener` en móvil,
/// `window.addEventListener('online', ...)` en web). Acá se centraliza en
/// un `StreamProvider` que ambas plataformas comparten sin código extra.
final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();

  bool isOnline(List<ConnectivityResult> results) =>
      results.isNotEmpty && !results.contains(ConnectivityResult.none);

  yield isOnline(await connectivity.checkConnectivity());

  yield* connectivity.onConnectivityChanged.map(isOnline).distinct();
});

/// Snapshot síncrono (con valor por defecto optimista `true`) para lugares
/// donde no conviene reconstruir todo el árbol de widgets por un `AsyncValue`.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityStreamProvider).valueOrNull ?? true;
});
