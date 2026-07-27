import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_tables.dart';
import '../models/perfil.dart';
import '../supabase/supabase_client_provider.dart';

/// Encapsula toda la interacción con Supabase Auth + tabla `perfiles`.
///
/// La creación de cuentas es exclusiva de administradores (Edge Function
/// `crear-usuario`). El autoregistro público está deshabilitado.
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

  Future<void> cerrarSesion() => _client.auth.signOut();

  /// Solicita una nueva contraseña autogenerada enviada por correo.
  Future<void> recuperarContrasena(String email) async {
    final response = await _client.functions.invoke(
      SupabaseFunctions.resetPassword,
      body: {'email': email.trim().toLowerCase()},
    );
    if (response.status != 200) {
      final data = response.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'No se pudo enviar la nueva contraseña.';
      throw Exception(message);
    }
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

  /// Actualiza solo el nombre del usuario autenticado (nunca de terceros).
  Future<void> actualizarNombrePropio(String nuevoNombre) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('No hay sesión activa.');
    }
    await actualizarNombre(userId, nuevoNombre);
  }

  /// Email de la sesión actual (`auth.users`), no de la tabla `perfiles`.
  String? get emailSesionActual => _client.auth.currentUser?.email;

  /// Cambia el rol de otro usuario. Usa el RPC `rpe_actualizar_rol_usuario`
  /// (`SECURITY DEFINER`) en vez de un `UPDATE` directo sobre `perfiles.rol`.
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

  /// Email de auth.users (solo admin; RPC `rpe_obtener_email_usuario`).
  Future<String?> obtenerEmailUsuario(String usuarioId) async {
    final result = await _client.rpc(
      SupabaseRpc.obtenerEmailUsuario,
      params: {'usuario_id': usuarioId},
    );
    return result as String?;
  }

  /// Elimina la cuenta de un usuario mediante el RPC `rpe_eliminar_usuario`.
  ///
  /// Devuelve `true` si la cuenta se eliminó por completo, `false` si otra
  /// aplicación de la base compartida aún referencia la cuenta y solo pudo
  /// desactivarse.
  Future<bool> eliminarUsuario(String usuarioId) async {
    final resultado = await _client.rpc(
      SupabaseRpc.eliminarUsuario,
      params: {'usuario_id': usuarioId},
    );
    return resultado == 'eliminado';
  }

  /// Solo un admin puede activar/desactivar cuentas.
  Future<void> establecerActivo(String id, bool activo) async {
    await _client
        .from(SupabaseTables.perfiles)
        .update({'activo': activo}).eq('id', id);
  }

  /// Crea un usuario (cualquier rol) y envía credenciales por correo.
  ///
  /// Para rol `externo`, pasar [eventoIds] (≥1). [eventoId] se mantiene por
  /// compatibilidad y se fusiona en la lista.
  Future<CrearUsuarioResultado> crearUsuario({
    required String nombreCompleto,
    required String email,
    required String password,
    required String rol,
    String? eventoId,
    List<String>? eventoIds,
  }) async {
    try {
      final ids = <String>{
        ...?eventoIds?.where((id) => id.isNotEmpty),
        if (eventoId != null && eventoId.isNotEmpty) eventoId,
      }.toList();

      final response = await _client.functions.invoke(
        SupabaseFunctions.crearUsuario,
        body: {
          'nombre_completo': nombreCompleto,
          'email': email.trim().toLowerCase(),
          'password': password,
          'rol': rol,
          if (ids.isNotEmpty) 'evento_ids': ids,
        },
      );

      if (response.status != 200) {
        final data = response.data;
        final message = data is Map && data['error'] != null
            ? data['error'].toString()
            : 'No se pudo crear el usuario.';
        throw Exception(message);
      }

      final data = response.data as Map<String, dynamic>;
      final nombresRaw = data['evento_nombres'];
      final nombres = nombresRaw is List
          ? nombresRaw.map((e) => e.toString()).toList()
          : <String>[];
      return CrearUsuarioResultado(
        userId: data['user_id'] as String,
        email: data['email'] as String,
        password: data['password'] as String,
        rol: data['rol'] as String? ?? rol,
        eventoNombre: data['evento_nombre'] as String?,
        eventoNombres: nombres,
      );
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['error'] != null) {
        throw Exception(details['error'].toString());
      }
      rethrow;
    }
  }

  /// IDs de eventos autorizados para un usuario (tabla `usuarios_eventos`).
  Future<List<String>> listarEventosAutorizadosUsuario(String usuarioId) async {
    final rows = await _client
        .from(SupabaseTables.usuariosEventos)
        .select('evento_id')
        .eq('usuario_id', usuarioId);
    return rows
        .map((r) => r['evento_id'] as String?)
        .whereType<String>()
        .toList();
  }

  /// Reemplaza el set de eventos autorizados de un externo (RPC admin).
  Future<void> sincronizarEventosExterno(
    String usuarioId,
    List<String> eventoIds,
  ) async {
    await _client.rpc(
      SupabaseRpc.sincronizarEventosExterno,
      params: {
        'p_usuario_id': usuarioId,
        'p_evento_ids': eventoIds,
      },
    );
  }

  /// Persiste el evento activo/preferido del externo autenticado.
  Future<void> actualizarEventoActivoExterno(String eventoId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from(SupabaseTables.perfiles)
        .update({'evento_asignado_id': eventoId}).eq('id', userId);
  }

  /// Genera nueva contraseña, la aplica y la envía por correo (solo admin).
  Future<RegenerarPasswordResultado> regenerarPasswordUsuario(
    String usuarioId,
  ) async {
    final response = await _client.functions.invoke(
      SupabaseFunctions.regenerarPasswordUsuario,
      body: {'user_id': usuarioId},
    );

    if (response.status != 200) {
      final data = response.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'No se pudo regenerar la contraseña.';
      throw Exception(message);
    }

    final data = response.data as Map<String, dynamic>;
    return RegenerarPasswordResultado(
      userId: data['user_id'] as String,
      email: data['email'] as String,
      password: data['password'] as String,
      nombreCompleto: data['nombre_completo'] as String? ?? '',
    );
  }
}

class CrearUsuarioResultado {
  const CrearUsuarioResultado({
    required this.userId,
    required this.email,
    required this.password,
    required this.rol,
    this.eventoNombre,
    this.eventoNombres = const [],
  });

  final String userId;
  final String email;
  final String password;
  final String rol;
  final String? eventoNombre;
  final List<String> eventoNombres;
}

class RegenerarPasswordResultado {
  const RegenerarPasswordResultado({
    required this.userId,
    required this.email,
    required this.password,
    required this.nombreCompleto,
  });

  final String userId;
  final String email;
  final String password;
  final String nombreCompleto;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});
