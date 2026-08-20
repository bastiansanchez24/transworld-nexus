import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/utils/mascara_contacto.dart';

void main() {
  group('enmascararEmail', () {
    test('deja dos caracteres de la parte local y del dominio', () {
      expect(
        enmascararEmail('maria.gonzalez@transworld.com'),
        'ma****@tr****.com',
      );
    });

    test('el subdominio queda dentro de la parte oculta', () {
      expect(
        enmascararEmail('maria@mail.transworld.com'),
        'ma****@ma****.com',
      );
    });

    test('no delata el largo de la parte local', () {
      expect(enmascararEmail('ana@x.cl'), enmascararEmail('anacleta@x.cl'));
    });

    test('oculta entero lo que es muy corto', () {
      expect(enmascararEmail('a@x.cl'), '**@**.cl');
      expect(enmascararEmail('ab@ex.cl'), '**@**.cl');
    });

    test('sin arroba enmascara todo menos los dos primeros', () {
      expect(enmascararEmail('correo-invalido'), 'co****');
    });

    test('un dominio sin punto también se enmascara', () {
      expect(enmascararEmail('maria@localhost'), 'ma****@lo****');
    });

    test('usa la última arroba como corte', () {
      expect(enmascararEmail('raro@parte@dominio.cl'), 'ra****@do****.cl');
    });

    test('nulo, vacío y espacios devuelven vacío', () {
      expect(enmascararEmail(null), '');
      expect(enmascararEmail(''), '');
      expect(enmascararEmail('   '), '');
    });
  });

  group('enmascararTelefono', () {
    test('deja visibles los últimos cuatro caracteres', () {
      expect(enmascararTelefono('+56 9 1234 5678'), '***********5678');
    });

    test('con cuatro caracteres o menos enmascara todo', () {
      expect(enmascararTelefono('5678'), '****');
      expect(enmascararTelefono('78'), '**');
    });

    test('nulo, vacío y espacios devuelven vacío', () {
      expect(enmascararTelefono(null), '');
      expect(enmascararTelefono(''), '');
      expect(enmascararTelefono('   '), '');
    });
  });
}
