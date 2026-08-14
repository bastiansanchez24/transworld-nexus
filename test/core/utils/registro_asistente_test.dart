import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/utils/registro_asistente.dart';

void main() {
  group('aTitleCase', () {
    test('capitaliza nombre y apellido con acentos', () {
      expect(aTitleCase('  maría   josé  gonzález '), 'María José González');
    });

    test('capitaliza tramos separados por guion', () {
      expect(aTitleCase('maría-josé perez'), 'María-José Perez');
    });

    test('baja todo a minúsculas antes de capitalizar', () {
      expect(aTitleCase('JUAN PEREZ'), 'Juan Perez');
    });
  });

  group('validarNombreCompleto', () {
    test('exige nombre y apellido', () {
      expect(validarNombreCompleto('Juan'), 'Ingresa nombre y apellido');
      expect(validarNombreCompleto('Juan Perez'), isNull);
    });

    test('rechaza vacío', () {
      expect(validarNombreCompleto('   '), 'Requerido');
      expect(validarNombreCompleto(null), 'Requerido');
    });
  });

  group('validarEmailRegistro', () {
    test('acepta un correo válido y lo trata en minúsculas', () {
      expect(validarEmailRegistro('  Ana.Diaz+tag@Empresa.CL '), isNull);
      expect(formatearEmail('  Ana.Diaz+tag@Empresa.CL '), 'ana.diaz+tag@empresa.cl');
    });

    test('rechaza formatos incompletos', () {
      expect(validarEmailRegistro('ana@empresa'), 'Email inválido');
      expect(validarEmailRegistro('ana.empresa.cl'), 'Email inválido');
      expect(validarEmailRegistro('ana@@empresa.cl'), 'Email inválido');
      expect(validarEmailRegistro('ana@empresa..cl'), 'Email inválido');
    });

    test('es obligatorio', () {
      expect(validarEmailRegistro(''), 'Requerido');
    });
  });

  group('validarTelefono Chile', () {
    test('acepta móvil 9 y fijo 2 de 9 dígitos', () {
      expect(validarTelefono('9 1234 5678', kPaisTelefonoChile), isNull);
      expect(validarTelefono('212345678', kPaisTelefonoChile), isNull);
    });

    test('rechaza otro prefijo o distinta cantidad', () {
      expect(
        validarTelefono('812345678', kPaisTelefonoChile),
        'En Chile el número debe empezar con 9 o 2',
      );
      expect(validarTelefono('91234567', kPaisTelefonoChile), 'Ingresa 9 dígitos');
    });

    test('recorta el código de país si se pega completo', () {
      expect(validarTelefono('+56 9 1234 5678', kPaisTelefonoChile), isNull);
      expect(
        telefonoInternacional('+56912345678', kPaisTelefonoChile),
        '+56 9 1234 5678',
      );
    });
  });

  group('validarTelefono otros países', () {
    test('valida por cantidad de dígitos', () {
      final peru = paisTelefonoPorIso('PE');
      expect(validarTelefono('912345678', peru), isNull);
      expect(validarTelefono('91234567', peru), 'Ingresa 9 dígitos');

      final mexico = paisTelefonoPorIso('MX');
      expect(validarTelefono('5512345678', mexico), isNull);
      expect(validarTelefono('551234567', mexico), 'Ingresa 10 dígitos');
    });
  });

  group('campos obligatorios', () {
    test('empresa y cargo no pueden quedar vacíos', () {
      expect(validarEmpresa('  '), 'Requerido');
      expect(validarEmpresa('Transworld'), isNull);
      expect(validarCargo(''), 'Requerido');
      expect(validarCargo('jefe comercial'), isNull);
      expect(formatearCargo('jefe comercial'), 'Jefe Comercial');
      expect(formatearEmpresa('  Acme  SPA '), 'Acme SPA');
    });
  });
}
