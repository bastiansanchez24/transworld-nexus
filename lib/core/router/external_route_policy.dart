import 'route_paths.dart';

/// Allowlist de rutas operativas para un usuario externo.
///
/// Las rutas técnicas de autenticación (por ejemplo, cambio obligatorio de
/// contraseña) se resuelven en el redirect global y deliberadamente no forman
/// parte de esta política de negocio.
bool isExternalOperationalRouteAllowed({
  required String location,
  required Set<String> authorizedEventIds,
  String? captureSourceEventId,
  bool hasTrustedScannerContext = false,
}) {
  for (final eventId in authorizedEventIds) {
    if (eventId.isEmpty) continue;
    if (location == RoutePaths.externoEvento(eventId)) return true;
    if (location == RoutePaths.acreditarQr(eventId)) return true;
  }

  if (!_isCaptureLeadRoute(location) || !hasTrustedScannerContext) return false;

  return captureSourceEventId != null &&
      captureSourceEventId.isNotEmpty &&
      authorizedEventIds.contains(captureSourceEventId);
}

bool _isCaptureLeadRoute(String location) {
  final parts = location.split('/');
  // ['', 'capturador', ':id', 'capturar']
  return parts.length == 4 &&
      parts[1] == 'capturador' &&
      parts[2].isNotEmpty &&
      parts[3] == 'capturar';
}
