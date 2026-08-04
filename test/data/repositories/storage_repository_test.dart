import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/data/repositories/storage_repository.dart';

void main() {
  group('agregarVersionCacheImagen', () {
    test('agrega una versión a una URL pública', () {
      expect(
        agregarVersionCacheImagen('https://example.test/perfil.jpg', 42),
        'https://example.test/perfil.jpg?v=42',
      );
    });

    test('conserva parámetros existentes', () {
      expect(
        agregarVersionCacheImagen(
          'https://example.test/perfil.jpg?width=320',
          42,
        ),
        'https://example.test/perfil.jpg?width=320&v=42',
      );
    });
  });
}
