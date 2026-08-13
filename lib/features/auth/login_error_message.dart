import 'package:supabase_flutter/supabase_flutter.dart';

const kMensajeCredencialesInvalidas = 'Correo o contraseña incorrectos.';
const kMensajeErrorInicioSesion = 'No se pudo iniciar sesión.';

/// Traduce el error de Auth a un mensaje corto para el usuario.
/// El detalle original no se muestra en crudo.
String mensajeErrorInicioSesion(Object error) {
  if (error is AuthException && _esCredencialInvalida(error)) {
    return kMensajeCredencialesInvalidas;
  }
  return kMensajeErrorInicioSesion;
}

bool _esCredencialInvalida(AuthException error) {
  final code = (error.code ?? '').toLowerCase();
  if (code == 'invalid_credentials' || code == 'invalid_grant') {
    return true;
  }
  final message = error.message.toLowerCase();
  return message.contains('invalid login credentials') ||
      message.contains('invalid email or password') ||
      message.contains('invalid_grant');
}
