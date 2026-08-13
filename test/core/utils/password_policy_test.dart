import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/utils/password_generator.dart';
import 'package:transworld_nexus/core/utils/password_policy.dart';

void main() {
  group('validarContrasenaFuerte', () {
    test('rechaza vacío y nulo', () {
      expect(validarContrasenaFuerte(null), 'Mínimo 8 caracteres');
      expect(validarContrasenaFuerte(''), 'Mínimo 8 caracteres');
    });

    test('rechaza menos de 8 caracteres', () {
      expect(validarContrasenaFuerte('Abc12#x'), 'Mínimo 8 caracteres');
    });

    test('rechaza si falta un grupo', () {
      expect(validarContrasenaFuerte('abcd12#x'), 'Debe incluir una mayúscula');
      expect(validarContrasenaFuerte('ABCD12#X'), 'Debe incluir una minúscula');
      expect(validarContrasenaFuerte('Abcdef#x'), 'Debe incluir un número');
      expect(
        validarContrasenaFuerte('Abcd1234'),
        'Debe incluir un símbolo (! # % \$)',
      );
    });

    test('acepta una contraseña que cumple los cuatro grupos', () {
      expect(validarContrasenaFuerte('Abcd12#x'), isNull);
      expect(validarContrasenaFuerte(r'Zz9$aaaa'), isNull);
    });

    test('no acepta símbolos fuera del conjunto permitido', () {
      expect(
        validarContrasenaFuerte('Abcd12&x'),
        'Debe incluir un símbolo (! # % \$)',
      );
    });
  });

  group('generarContrasenaInvitacion', () {
    test('genera 8 caracteres que cumplen la política', () {
      for (var i = 0; i < 500; i++) {
        final password = generarContrasenaInvitacion();
        expect(password.length, kPasswordMinLength);
        expect(validarContrasenaFuerte(password), isNull, reason: password);
      }
    });

    test('respeta un largo mayor y sigue cumpliendo la política', () {
      final password = generarContrasenaInvitacion(length: 16);
      expect(password.length, 16);
      expect(validarContrasenaFuerte(password), isNull, reason: password);
    });

    test('no repite siempre la misma contraseña', () {
      final generadas = {for (var i = 0; i < 50; i++) generarContrasenaInvitacion()};
      expect(generadas.length, greaterThan(40));
    });
  });
}
