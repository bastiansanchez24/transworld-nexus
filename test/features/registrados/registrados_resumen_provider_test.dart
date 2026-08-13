import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transworld_nexus/data/models/registrado.dart';
import 'package:transworld_nexus/data/offline/sync_queue_service.dart';
import 'package:transworld_nexus/features/registrados/providers/registrados_providers.dart';

void main() {
  const eventoId = 'evento-1';

  Registrado registrado(String id, {bool acreditado = false}) => Registrado(
    id: id,
    eventoId: eventoId,
    nombreCompleto: id,
    email: '$id@empresa.com',
    acreditado: acreditado,
  );

  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    preferences = await SharedPreferences.getInstance();
  });

  ProviderContainer contenedor(List<Registrado> servidor) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        syncQueueActiveOwnerIdProvider.overrideWithValue('owner-1'),
        registradosPorEventoProvider.overrideWith((ref, id) async => servidor),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('abrir el evento carga la lista y de ahí salen los conteos', () async {
    final container = contenedor([
      registrado('ana', acreditado: true),
      registrado('bruno'),
      registrado('carla'),
    ]);

    // Antes de que responda el servidor no hay nada cacheado todavía.
    expect(container.read(registradosResumenProvider(eventoId)), isNull);

    await container.read(registradosPorEventoProvider(eventoId).future);
    final resumen = container.read(registradosResumenProvider(eventoId));

    expect(resumen?.total, 3);
    expect(resumen?.acreditados, 1);
    expect(resumen?.pendientes, 2);
  });

  test('un evento sin gente registrada informa cero, no "—"', () async {
    final container = contenedor(const []);

    await container.read(registradosPorEventoProvider(eventoId).future);
    final resumen = container.read(registradosResumenProvider(eventoId));

    expect(resumen?.total, 0);
    expect(resumen?.acreditados, 0);
  });

  test('resumenDesdeRegistrados separa acreditados de pendientes', () {
    final resumen = resumenDesdeRegistrados([
      registrado('ana', acreditado: true),
      registrado('bruno', acreditado: true),
      registrado('carla'),
    ]);

    expect(resumen.total, 3);
    expect(resumen.acreditados, 2);
    expect(resumen.pendientes, 1);
  });
}
