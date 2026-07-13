import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_tables.dart';
import '../models/perfil.dart';
import '../supabase/supabase_client_provider.dart';

/// Encapsula toda la interacción con Supabase Auth + tabla `perfiles`.
///
/// A diferencia del `authService.ts` legado (duplicado byte a byte entre
/// las dos apps, con pequeñas divergencias de caché local — ver
/// documentacion_zips_registro_pro.md Sección 3.8/4.8), acá hay una sola
/// implementación para las tres plataformas (móvil, web, escritorio).
///
/// También se simplifica el flujo de registro: en el legado, `registrarUsuario`
/// tenía que lidiar manualmente con "usuario ofuscado" y "ya existe en
/// auth.users" porque el proyecto compartía autenticación con la app hermana
/// "capturador-leads". Ese manejo especial ahora vive del lado del backend
/// (trigger `rpe_handle_new_user`, ver supabase/schema.sql), así que el
/// cliente solo necesita llamar `signUp` de forma estándar.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> iniciarSesion({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> registrarUsuario({
    required String email,
    required String password,
    required String nombreCompleto,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'nombre_completo': nombreCompleto},
    );
  }

  Future<void> cerrarSesion() => _client.auth.signOut();

  Future<void> recuperarContrasena(String email) async {
    await _client.rpc(
      SupabaseRpc.marcarRecuperacionPass,
      params: {'email_input': email},
    );
    await _client.functions.invoke(
      SupabaseFunctions.resetPassword,
      body: {'email': email},
    );
  }

  Future<bool> verificarEmailRegistrado(String email) async {
    final result = await _client.rpc(
      SupabaseRpc.verificarUsuarioRegistrado,
      params: {'email_check': email},
    );
    return result as bool;
  }

  Future<void> actualizarContrasena(String nuevaContrasena) async {
    await _client.auth.updateUser(UserAttributes(password: nuevaContrasena));
  }

  Future<void> forzarNuevaContrasena(String nuevaContrasena) async {
    await actualizarContrasena(nuevaContrasena);
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from(SupabaseTables.perfiles)
        .update({'cambiar_pass': false}).eq('id', userId);
  }

  Future<Perfil?> obtenerPerfilActual() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from(SupabaseTables.perfiles)
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Perfil.fromMap(row);
  }

  Future<void> actualizarNombre(String id, String nuevoNombre) async {
    await _client
        .from(SupabaseTables.perfiles)
        .update({'nombre_completo': nuevoNombre}).eq('id', id);
  }

  /// Cambia el rol de otro usuario. Usa el RPC `rpe_actualizar_rol_usuario`
  /// (`SECURITY DEFINER`) en vez de un `UPDATE` directo sobre `perfiles.rol`:
  /// es la corrección al hallazgo crítico de escalación de privilegios
  /// documentado en la Sección 8.2/17.6 (la policy de `perfiles` por sí sola
  /// no puede impedir que un usuario se autoasigne rol admin; ahora, además
  /// del trigger de base de datos, el cliente ni siquiera intenta el camino
  /// inseguro).
  Future<void> actualizarRolUsuario(String usuarioId, String nuevoRol) async {
    await _client.rpc(
      SupabaseRpc.actualizarRolUsuario,
      params: {'usuario_id': usuarioId, 'nuevo_rol': nuevoRol},
    );
  }

  Future<List<Perfil>> obtenerTodosLosUsuarios() async {
    final rows = await _client
        .from(SupabaseTables.perfiles)
        .select()
        .neq('id', SupabaseTables.perfilUsuarioEliminadoId)
        .order('nombre_completo');
    return rows
        .map(Perfil.fromMap)
        .where((p) => p.id != SupabaseTables.perfilUsuarioEliminadoId)
        .toList();
  }

  Future<Perfil> obtenerUsuarioPorId(String id) async {
    final row = await _client
        .from(SupabaseTables.perfiles)
        .select()
        .eq('id', id)
        .single();
    return Perfil.fromMap(row);
  }

  /// Elimina la cuenta de un usuario mediante el RPC `rpe_eliminar_usuario`
  /// (`SECURITY DEFINER`). Las acreditaciones (`acreditado_por`) se
  /// reasignan al perfil sistema "Usuario eliminado"; otras FKs
  /// históricas (`ingresado_por`, `creado_por`, etc.) quedan en NULL.
  /// El RPC rechaza la operación si quien la ejecuta no es admin o
  /// intenta eliminarse a sí mismo.
  ///
  /// Devuelve `true` si la cuenta se eliminó por completo, `false` si otra
  /// aplicación de la base compartida aún referencia la cuenta y solo pudo
  /// desactivarse (ban permanente: pierde el acceso igualmente).
  Future<bool> eliminarUsuario(String usuarioId) async {
    final resultado = await _client.rpc(
      SupabaseRpc.eliminarUsuario,
      params: {'usuario_id': usuarioId},
    );
    return resultado == 'eliminado';
  }

  /// Solo un admin puede activar/desactivar cuentas (lo hace cumplir el
  /// trigger `rpe_prevent_role_self_escalation` en la base de datos).
  Future<void> establecerActivo(String id, bool activo) async {
    await _client
        .from(SupabaseTables.perfiles)
        .update({'activo': activo}).eq('id', id);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});
