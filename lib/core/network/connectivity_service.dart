import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
