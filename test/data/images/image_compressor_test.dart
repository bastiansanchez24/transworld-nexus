import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:transworld_nexus/data/images/image_compressor.dart';

/// Foto sintética con degradado y ruido: una imagen plana se comprimiría a
/// casi nada y el test no diría nada útil sobre el ahorro real.
img.Image _fotoDePrueba(int ancho, int alto) {
  final imagen = img.Image(width: ancho, height: alto);
  for (var y = 0; y < alto; y++) {
    for (var x = 0; x < ancho; x++) {
      imagen.setPixelRgb(x, y, x % 256, y % 256, (x * y) % 256);
    }
  }
  return imagen;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('comprimirParaSubida', () {
    test('reduce el lado largo al máximo configurado', () async {
      final original = img.encodePng(_fotoDePrueba(3000, 2000));

      final comprimida = await comprimirParaSubida(original);

      final decodificada = img.decodeImage(comprimida)!;
      expect(decodificada.width, kLadoMaximoSubida);
      expect(decodificada.height, 683); // 2000 * 1024 / 3000
    });

    test('respeta la orientación vertical', () async {
      final original = img.encodePng(_fotoDePrueba(2000, 3000));

      final decodificada = img.decodeImage(await comprimirParaSubida(original))!;

      expect(decodificada.height, kLadoMaximoSubida);
      expect(decodificada.width, 683);
    });

    test('no agranda una imagen que ya es chica', () async {
      final original = img.encodePng(_fotoDePrueba(320, 240));

      final decodificada = await comprimirParaSubida(original)
          .then((bytes) => img.decodeImage(bytes)!);

      expect(decodificada.width, 320);
      expect(decodificada.height, 240);
    });

    test('siempre entrega JPEG, aunque entre un PNG', () async {
      final original = img.encodePng(_fotoDePrueba(1200, 900));

      final comprimida = await comprimirParaSubida(original);

      // Magic number de JPEG (SOI): FF D8 FF.
      expect(comprimida.sublist(0, 3), [0xFF, 0xD8, 0xFF]);
    });

    test('pesa bastante menos que el original', () async {
      final original = img.encodePng(_fotoDePrueba(3000, 2000));

      final comprimida = await comprimirParaSubida(original);

      // El patrón sintético es ruido puro, el peor caso posible para JPEG:
      // una foto real baja mucho más. Aun así tiene que quedar holgadamente
      // por debajo del objetivo de la compresión agresiva, que es subir con
      // datos móviles sin dolor.
      expect(comprimida.length, lessThan(original.length ~/ 4));
      expect(comprimida.length, lessThan(150 * 1024));
    });

    test('recorta a cuadrado una foto apaisada', () async {
      final original = img.encodePng(_fotoDePrueba(2000, 1000));

      final decodificada = await comprimirParaSubida(
        original,
        recorteProporcion: 1,
      ).then((bytes) => img.decodeImage(bytes)!);

      expect(decodificada.width, decodificada.height);
      // El lado del recorte es el lado corto (1000), que ya está por debajo
      // del máximo, así que no se reescala.
      expect(decodificada.width, 1000);
    });

    test('recorta a cuadrado una foto vertical y la escala al máximo',
        () async {
      final original = img.encodePng(_fotoDePrueba(1500, 3000));

      final decodificada = await comprimirParaSubida(
        original,
        recorteProporcion: 1,
      ).then((bytes) => img.decodeImage(bytes)!);

      expect(decodificada.width, kLadoMaximoSubida);
      expect(decodificada.height, kLadoMaximoSubida);
    });

    test('sin recorte conserva la proporción original', () async {
      final original = img.encodePng(_fotoDePrueba(2000, 1000));

      final decodificada = await comprimirParaSubida(original)
          .then((bytes) => img.decodeImage(bytes)!);

      expect(decodificada.width / decodificada.height, closeTo(2, 0.01));
    });

    test('una imagen que ya es cuadrada no se recorta', () async {
      final original = img.encodePng(_fotoDePrueba(600, 600));

      final decodificada = await comprimirParaSubida(
        original,
        recorteProporcion: 1,
      ).then((bytes) => img.decodeImage(bytes)!);

      expect(decodificada.width, 600);
      expect(decodificada.height, 600);
    });

    test('falla con un mensaje claro si no es una imagen', () async {
      expect(
        () => comprimirParaSubida(img.encodePng(_fotoDePrueba(2, 2))
            .sublist(0, 4)),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
