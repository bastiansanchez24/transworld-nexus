import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transworld_nexus/data/models/lead.dart';
import 'package:transworld_nexus/data/offline/offline_read_cache.dart';

void main() {
  const tabla = 'leads';
  const eventoId = 'evento-1';

  final lead = Lead(
    id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    eventoId: eventoId,
    nombreCompleto: 'María González',
    empresa: 'Transworld',
    cargo: 'Gerente comercial',
    email: 'maria@transworld.cl',
    descripcion: 'Interesada en el plan anual.',
    createdAt: DateTime.utc(2026, 3, 14, 9, 30),
    vendedorNombre: 'Pedro Soto',
  );

  Future<OfflineReadCache> nuevaCache() async {
    SharedPreferences.setMockInitialValues({});
    return OfflineReadCache(await SharedPreferences.getInstance());
  }

  Future<List<Lead>> leer(
    OfflineReadCache cache, {
    required Future<List<Lead>> Function() desdeServidor,
    String evento = eventoId,
  }) {
    return cache.leerConRespaldo<Lead>(
      tabla: tabla,
      eventoId: evento,
      desdeServidor: desdeServidor,
      aFila: (l) => l.toCacheMap(),
      desdeFila: Lead.fromMap,
    );
  }

  group('OfflineReadCache.leerConRespaldo', () {
    test('con servidor disponible devuelve lo fresco y guarda la copia',
        () async {
      final cache = await nuevaCache();

      final frescos = await leer(cache, desdeServidor: () async => [lead]);

      expect(frescos.single.nombreCompleto, 'María González');

      // La segunda lectura ya puede caer a la copia guardada.
      final desdeCache = await leer(
        cache,
        desdeServidor: () async => throw Exception('sin red'),
      );
      expect(desdeCache.single.nombreCompleto, 'María González');
    });

    test('cuando el servidor falla sirve la última copia sin perder campos',
        () async {
      final cache = await nuevaCache();
      await leer(cache, desdeServidor: () async => [lead]);

      final desdeCache = await leer(
        cache,
        desdeServidor: () async => throw Exception('sin red'),
      );

      final revivido = desdeCache.single;
      expect(revivido.id, lead.id);
      expect(revivido.empresa, lead.empresa);
      expect(revivido.cargo, lead.cargo);
      expect(revivido.email, lead.email);
      expect(revivido.descripcion, lead.descripcion);
      expect(revivido.createdAt, lead.createdAt);
      expect(revivido.vendedorNombre, lead.vendedorNombre);
    });

    test('sin copia previa propaga el error en vez de mentir con una lista vacía',
        () async {
      final cache = await nuevaCache();

      expect(
        () => leer(cache, desdeServidor: () async => throw Exception('sin red')),
        throwsA(isA<Exception>()),
      );
    });

    test('la copia de un evento no responde por otro', () async {
      final cache = await nuevaCache();
      await leer(cache, desdeServidor: () async => [lead]);

      expect(
        () => leer(
          cache,
          evento: 'otro-evento',
          desdeServidor: () async => throw Exception('sin red'),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('una carga posterior reemplaza la copia anterior', () async {
      final cache = await nuevaCache();
      await leer(cache, desdeServidor: () async => [lead]);

      final renombrado = lead.conCambiosPendientes({
        'nombre_completo': 'María González Pérez',
      });
      await leer(cache, desdeServidor: () async => [renombrado]);

      final desdeCache = await leer(
        cache,
        desdeServidor: () async => throw Exception('sin red'),
      );
      expect(desdeCache.single.nombreCompleto, 'María González Pérez');
    });
  });
}
