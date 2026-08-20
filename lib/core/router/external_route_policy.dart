import 'route_paths.dart';

/// Rutas de cuenta que un externo puede abrir desde su menú de ajustes.
///
/// No dependen de un evento: son su propia ficha y el estado del dispositivo.
/// Notificaciones queda fuera a propósito —el externo no tiene campana— igual
/// que todo el shell interno.
const Set<String> _rutasDeCuentaExterno = {
  RoutePaths.perfil,
  RoutePaths.sincronizacion,
  RoutePaths.actualizaciones,
};

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
  if (_rutasDeCuentaExterno.contains(location)) return true;

  for (final eventId in authorizedEventIds) {
    if (eventId.isEmpty) continue;
    if (location == RoutePaths.externoEvento(eventId)) return true;
    if (location == RoutePaths.acreditarQr(eventId)) return true;
  }

  if (!_isCaptureLeadRoute(location) && !_isLeadVisibilityRoute(location)) {
    return false;
  }

  // Capturar, listar y comentar leads cuelgan del evento de registro
  // asignado. El id de campaña vive en la URL; lo que autoriza es
  // `desdeEvento`. RLS sigue acotando las filas.
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

bool _isLeadVisibilityRoute(String location) {
  final parts = location.split('/');
  if (parts.length < 4) return false;
  if (parts[1] != 'capturador' || parts[2].isEmpty || parts[3] != 'leads') {
    return false;
  }
  if (parts.length == 4) return true;
  if (parts.length == 5) return parts[4].isNotEmpty;
  return parts.length == 6 && parts[4].isNotEmpty && parts[5] == 'comentarios';
}
