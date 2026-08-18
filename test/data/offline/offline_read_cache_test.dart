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
    return OfflineReadCache(
      await SharedPreferences.getInstance(),
      ownerId: 'usuario-a',
    );
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
      isOnline: false,
    );
  }

  group('OfflineReadCache.leerConRespaldo', () {
    test(
      'con servidor disponible devuelve lo fresco y guarda la copia',
      () async {
        final cache = await nuevaCache();

        final frescos = await leer(cache, desdeServidor: () async => [lead]);

        expect(frescos.single.nombreCompleto, 'María González');

        // La segunda lectura ya puede caer a la copia guardada.
        final desdeCache = await leer(
          cache,
          desdeServidor: () async => throw Exception('Failed host lookup'),
        );
        expect(desdeCache.single.nombreCompleto, 'María González');
      },
    );

    test(
      'cuando el servidor falla sirve la última copia sin perder campos',
      () async {
        final cache = await nuevaCache();
        await leer(cache, desdeServidor: () async => [lead]);

        final desdeCache = await leer(
          cache,
          desdeServidor: () async => throw Exception('Failed host lookup'),
        );

        final revivido = desdeCache.single;
        expect(revivido.id, lead.id);
        expect(revivido.empresa, lead.empresa);
        expect(revivido.cargo, lead.cargo);
        expect(revivido.email, lead.email);
        expect(revivido.descripcion, lead.descripcion);
        expect(revivido.createdAt, lead.createdAt);
        expect(revivido.vendedorNombre, lead.vendedorNombre);
      },
    );

    test(
      'sin copia previa propaga el error en vez de mentir con una lista vacía',
      () async {
        final cache = await nuevaCache();

        expect(
          () => leer(
            cache,
            desdeServidor: () async => throw Exception('Failed host lookup'),
          ),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('la copia de un evento no responde por otro', () async {
      final cache = await nuevaCache();
      await leer(cache, desdeServidor: () async => [lead]);

      expect(
        () => leer(
          cache,
          evento: 'otro-evento',
          desdeServidor: () async => throw Exception('Failed host lookup'),
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
        desdeServidor: () async => throw Exception('Failed host lookup'),
      );
      expect(desdeCache.single.nombreCompleto, 'María González Pérez');
    });

    test(
      'un 403 jamás revive la copia aunque el dispositivo figure offline',
      () async {
        final cache = await nuevaCache();
        await leer(cache, desdeServidor: () async => [lead]);

        expect(
          () => leer(
            cache,
            desdeServidor: () async => throw Exception('403 permission denied'),
          ),
          throwsA(isA<Exception>()),
        );

        // La denegación purga la copia: una desconexión posterior no puede
        // volver a mostrar el evento revocado.
        expect(
          () => leer(
            cache,
            desdeServidor: () async => throw Exception('Failed host lookup'),
          ),
          throwsA(isA<Exception>()),
        );
      },
    );

    test(
      'una lista de autorizaciones resuelta purga eventos revocados',
      () async {
        final cache = await nuevaCache();
        await leer(cache, desdeServidor: () async => [lead]);
        await cache.retenerEventos(tabla, const {'otro-evento'});

        expect(
          () => leer(
            cache,
            desdeServidor: () async => throw Exception('Failed host lookup'),
          ),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('un rol privado purga filas cacheadas de otros perfiles', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cache = OfflineReadCache(prefs, ownerId: 'usuario-a');
      await cache.guardar(tabla, eventoId, [
        {...lead.toCacheMap(), 'perfil_id': 'usuario-a'},
        {...lead.toCacheMap(), 'id': 'lead-ajeno', 'perfil_id': 'usuario-b'},
      ]);

      await cache.retenerFilasPropias(tabla, 'usuario-a');
      final visibles = await leer(
        cache,
        desdeServidor: () async => throw Exception('Failed host lookup'),
      );
      expect(visibles.map((item) => item.id), [lead.id]);
    });

    test('cada usuario lee únicamente su namespace', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cacheA = OfflineReadCache(prefs, ownerId: 'usuario-a');
      final cacheB = OfflineReadCache(prefs, ownerId: 'usuario-b');
      await leer(cacheA, desdeServidor: () async => [lead]);

      expect(
        () => cacheB.leerConRespaldo<Lead>(
          tabla: tabla,
          eventoId: eventoId,
          desdeServidor: () async => throw Exception('Failed host lookup'),
          aFila: (l) => l.toCacheMap(),
          desdeFila: Lead.fromMap,
          isOnline: false,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('leerLocal devuelve la copia guardada sin ir al servidor', () async {
      final cache = await nuevaCache();
      await cache.guardar(tabla, eventoId, [lead.toCacheMap()]);

      final local = cache.leerLocal(
        tabla: tabla,
        eventoId: eventoId,
        desdeFila: Lead.fromMap,
      );
      expect(local, isNotNull);
      expect(local!.single.nombreCompleto, 'María González');
      expect(
        cache.leerLocal(
          tabla: tabla,
          eventoId: 'otro',
          desdeFila: Lead.fromMap,
        ),
        isNull,
      );
    });
  });
}
