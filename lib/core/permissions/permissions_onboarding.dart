import 'package:shared_preferences/shared_preferences.dart';

/// Marca local por usuario para pedir permisos runtime una sola vez
/// por dispositivo (cámara, mic, fotos, notificaciones, etc.).
class PermissionsOnboarding {
  PermissionsOnboarding(this._prefs);

  final SharedPreferences _prefs;

  static String _key(String userId) => 'permissions_requested_$userId';

  bool yaSolicitados(String userId) =>
      _prefs.getBool(_key(userId)) ?? false;

  Future<void> marcarSolicitados(String userId) =>
      _prefs.setBool(_key(userId), true);
}
