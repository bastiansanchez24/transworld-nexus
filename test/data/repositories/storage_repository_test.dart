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

  group('paths privados de fotos de leads', () {
    test('reconoce path privado y preserva URL pública legacy', () {
      expect(esFotoStorageLead('leads/abc.jpg'), isTrue);
      expect(
        esFotoStorageLead(
          'https://demo.supabase.co/storage/v1/object/public/imagenes/leads/abc.jpg',
        ),
        isFalse,
      );
    });

    test('extrae el path de una URL firmada sin persistir el token', () {
      expect(
        pathFotoStorageLead(
          'https://demo.supabase.co/storage/v1/object/sign/'
          'leads-privados/leads/abc.jpg?token=secreto',
        ),
        'leads/abc.jpg',
      );
    });
  });
}
