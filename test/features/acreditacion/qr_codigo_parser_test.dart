import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:transworld_nexus/features/acreditacion/qr_codigo_parser.dart';

void main() {
  const uuid = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

  group('extraerRegistradoIdDeTexto', () {
    test('acepta UUID plano', () {
      expect(extraerRegistradoIdDeTexto(uuid), uuid);
    });

    test('acepta UUID con espacios', () {
      expect(extraerRegistradoIdDeTexto('  $uuid  '), uuid);
    });

    test('acepta JSON con registrado_id', () {
      expect(
        extraerRegistradoIdDeTexto('{"registrado_id":"$uuid"}'),
        uuid,
      );
    });

    test('acepta URL con query param', () {
      expect(
        extraerRegistradoIdDeTexto('https://app.com/acreditar?registrado_id=$uuid'),
        uuid,
      );
    });

    test('rechaza texto sin UUID', () {
      expect(extraerRegistradoIdDeTexto('hola mundo'), isNull);
    });
  });

  group('extraerRegistradoIdDeBarcode', () {
    test('usa displayValue si rawValue es null', () {
      const barcode = Barcode(displayValue: uuid);
      expect(extraerRegistradoIdDeBarcode(barcode), uuid);
    });
  });
}
