import 'route_paths.dart';

/// Destino mientras hay sesión y el perfil de negocio aún no llegó.
///
/// No abre el shell (faltan rol y permisos) ni el formulario de login: en web
/// eso provocaba un flash del login antes de avanzar al home. `null` = quedarse
/// en la ruta actual (splash, login post-submit, o una pública como el
/// registro).
String? rutaMientrasCargaPerfil({
  required String location,
  required bool esPublica,
  required bool perfilFallido,
}) {
  if (perfilFallido) return RoutePaths.login;
  if (location == RoutePaths.splash || location == RoutePaths.login) {
    return null;
  }
  if (esPublica) return null;
  return RoutePaths.splash;
}
