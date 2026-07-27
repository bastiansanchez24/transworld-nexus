/// Nombres de tablas, columnas y RPCs de Supabase, en un solo lugar.
///
/// Evita repetir strings mágicos (`'registrados'`, `'evento_id'`, etc.) por
/// todas las pantallas, como ocurría en el proyecto legado. Todas las
/// tablas viven en el esquema `public` (ver supabase/schema.sql).
class SupabaseTables {
  SupabaseTables._();

  static const perfiles = 'perfiles';
  static const eventos = 'eventos';
  static const registrados = 'registrados';
  static const usuariosEventos = 'usuarios_eventos';

  /// Eventos del módulo Capturador de leads (tabla independiente de [eventos]).
  static const eventosLeads = 'eventos_leads';
  static const leads = 'leads';

  /// Perfil sistema al que se reasignan las FKs históricas
  /// (`acreditado_por`, `ingresado_por`, `creado_por`, `perfil_id` de
  /// leads) al eliminar un usuario. No debe listarse en la UI de gestión.
  static const perfilUsuarioEliminadoId =
      '00000000-0000-0000-0000-000000000001';
}

class SupabaseRpc {
  SupabaseRpc._();

  static const marcarRecuperacionPass = 'marcar_recuperacion_pass';
  static const verificarUsuarioRegistrado = 'verificar_usuario_registrado';
  static const actualizarRolUsuario = 'rpe_actualizar_rol_usuario';
  static const eliminarUsuario = 'rpe_eliminar_usuario';
  static const obtenerEmailUsuario = 'rpe_obtener_email_usuario';
  static const sincronizarEventosExterno = 'rpe_sincronizar_eventos_externo';
}

class SupabaseFunctions {
  SupabaseFunctions._();

  static const resetPassword = 'reset-password';
  static const enviarQr = 'enviar-qr';
  static const crearUsuario = 'crear-usuario';
  static const regenerarPasswordUsuario = 'regenerar-password-usuario';
}
