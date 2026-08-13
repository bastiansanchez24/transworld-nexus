import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:transworld_nexus/features/auth/login_error_message.dart';

void main() {
  test('credenciales inválidas se muestran en español', () {
    expect(
      mensajeErrorInicioSesion(
        const AuthException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
      ),
      kMensajeCredencialesInvalidas,
    );
    expect(
      mensajeErrorInicioSesion(
        const AuthException('Invalid login credentials'),
      ),
      kMensajeCredencialesInvalidas,
    );
  });

  test('cualquier otro error muestra un mensaje genérico', () {
    expect(
      mensajeErrorInicioSesion(
        const AuthException('Email not confirmed', code: 'email_not_confirmed'),
      ),
      kMensajeErrorInicioSesion,
    );
    expect(
      mensajeErrorInicioSesion(Exception('socket hang up')),
      kMensajeErrorInicioSesion,
    );
    expect(
      mensajeErrorInicioSesion('AuthRetryableFetchException'),
      kMensajeErrorInicioSesion,
    );
  });
}
