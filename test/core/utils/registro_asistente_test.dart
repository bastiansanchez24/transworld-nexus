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
      expect(
        formatearEmail('  Ana.Diaz+tag@Empresa.CL '),
        'ana.diaz+tag@empresa.cl',
      );
    });

    test('rechaza formatos incompletos', () {
      expect(validarEmailRegistro('ana@empresa'), 'Email inválido');
      expect(validarEmailRegistro('ana.empresa.cl'), 'Email inválido');
      expect(validarEmailRegistro('ana@@empresa.cl'), 'Email inválido');
      expect(validarEmailRegistro('ana@empresa..cl'), 'Email inválido');
    });

    test('es obligatorio', () {
      expect(validarEmailRegistro(''), 'Requerido');
      expect(validarEmailRegistro('', requerido: false), isNull);
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
      expect(
        validarTelefono('91234567', kPaisTelefonoChile),
        'Ingresa 9 dígitos',
      );
    });

    test('recorta el código de país si se pega completo', () {
      expect(validarTelefono('+56 9 1234 5678', kPaisTelefonoChile), isNull);
      expect(
        telefonoInternacional('+56912345678', kPaisTelefonoChile),
        '+56 9 1234 5678',
      );
    });

    test('al formatear recorta dígitos extra según el máximo del país', () {
      expect(
        formatearTelefonoNacional('9123456789', kPaisTelefonoChile),
        '9 1234 5678',
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

    test('Chile y Perú aparecen primero y derivan del país del evento', () {
      expect(kPaisesTelefono.take(2).map((pais) => pais.iso), ['CL', 'PE']);
      expect(paisTelefonoPorPaisEvento('Chile').iso, 'CL');
      expect(paisTelefonoPorPaisEvento('Perú').iso, 'PE');
      expect(detectarPaisTelefono('+51 912345678')?.iso, 'PE');
      expect(detectarPaisTelefono('+56 9 1234 5678')?.iso, 'CL');
    });

    test(
      'un teléfono opcional vacío no falla pero uno escrito sí se valida',
      () {
        expect(
          validarTelefono('', kPaisTelefonoChile, requerido: false),
          isNull,
        );
        expect(
          validarTelefono('123', kPaisTelefonoChile, requerido: false),
          'Ingresa 9 dígitos',
        );
      },
    );
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

  group('validarRut Chile', () {
    test('acepta un RUT con DV correcto y lo formatea', () {
      expect(validarRut('123456785'), isNull);
      expect(formatearRut('123456785'), '12.345.678-5');
      expect(validarRut('12.345.678-5'), isNull);
      expect(validarRut('12.345.670-K'), isNull);
      expect(formatearRut('12345670k'), '12.345.670-K');
    });

    test('rechaza DV incorrecto', () {
      expect(validarRut('12.345.678-9'), 'RUT inválido');
      expect(validarRut('12345678-0'), 'RUT inválido');
    });

    test('vacío solo falla si es requerido', () {
      expect(validarRut(''), 'Requerido');
      expect(validarRut('', requerido: false), isNull);
      expect(validarRut(null, requerido: false), isNull);
    });

    test('fuera de Chile valida un RUC genérico', () {
      expect(validarRut('20123456789', esChile: false), isNull);
      expect(validarRut('ab', esChile: false), 'RUC inválido');
      expect(validarRut('', esChile: false, requerido: false), isNull);
    });
  });

  group('validarPatente', () {
    test('acepta formato vigente y antiguo', () {
      expect(validarPatente('ABCD12'), isNull);
      expect(validarPatente('ab-cd-12'), isNull);
      expect(formatearPatente('ab-cd-12'), 'ABCD12');
      expect(validarPatente('AB1234'), isNull);
      expect(validarPatente('ab-12-34'), isNull);
    });

    test('rechaza longitudes o símbolos imposibles', () {
      expect(validarPatente('12'), 'Patente inválida');
      expect(validarPatente('ABCDE1'), 'Patente inválida');
      expect(validarPatente('AB12'), 'Patente inválida');
    });

    test('vacío solo falla si es requerido', () {
      expect(validarPatente(''), 'Requerido');
      expect(validarPatente('', requerido: false), isNull);
    });
  });
}
