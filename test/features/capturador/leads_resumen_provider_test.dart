import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transworld_nexus/core/constants/app_role.dart';
import 'package:transworld_nexus/data/models/lead.dart';
import 'package:transworld_nexus/data/models/perfil.dart';
import 'package:transworld_nexus/data/offline/offline_read_cache.dart';
import 'package:transworld_nexus/data/offline/sync_queue_service.dart';
import 'package:transworld_nexus/features/auth/providers/auth_providers.dart';
import 'package:transworld_nexus/features/capturador/providers/capturador_providers.dart';

void main() {
  const eventoId = 'campana-1';
  const perfilUser = Perfil(
    id: 'user-1',
    nombreCompleto: 'Usuario Interno',
    rol: AppRole.user,
  );
  const perfilAdmin = Perfil(
    id: 'admin-1',
    nombreCompleto: 'Admin',
    rol: AppRole.admin,
  );
  const perfilExterno = Perfil(
    id: 'externo-1',
    nombreCompleto: 'Usuario Externo',
    rol: AppRole.externo,
  );

  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    preferences = await SharedPreferences.getInstance();
  });

  Future<ProviderContainer> contenedor({
    required Perfil perfil,
    LeadsResumen? remoto,
    List<Lead> enCache = const [],
  }) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        syncQueueActiveOwnerIdProvider.overrideWithValue(perfil.id),
        currentPerfilProvider.overrideWith((ref) async => perfil),
        leadsResumenRemotoProvider.overrideWith((ref, id) async {
          if (remoto == null) {
            // Simula el RPC caído o todavía sin desplegar.
            throw Exception('rpc no disponible');
          }
          return remoto;
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(currentPerfilProvider.future);
    if (enCache.isNotEmpty) {
      await container
          .read(offlineReadCacheProvider)
          .guardar(
            leadsCacheTabla(perfil.canViewAllLeads),
            eventoId,
            enCache.map((lead) => lead.toCacheMap()).toList(),
          );
    }
    // Deja resolver el resumen remoto (o su error) antes de leer el local.
    await container
        .read(leadsResumenRemotoProvider(eventoId).future)
        .then<void>((_) {}, onError: (_) {});
    return container;
  }

  Lead lead(String id, {String? empresa}) =>
      Lead(id: id, eventoId: eventoId, nombreCompleto: id, empresa: empresa);

  test(
    'el resumen del servidor manda, aunque el rol solo vea sus leads',
    () async {
      final container = await contenedor(
        perfil: perfilUser,
        remoto: const LeadsResumen(total: 12, empresas: 5),
        enCache: [lead('propio')],
      );

      final resumen = container.read(leadsResumenLocalProvider(eventoId));

      expect(resumen?.total, 12);
      expect(resumen?.empresas, 5);
    },
  );

  test(
    'sin resumen del servidor no se pasa el conteo propio como total de la campaña',
    () async {
      // El externo es el único rol cuya caché contiene solo sus propios leads.
      final container = await contenedor(
        perfil: perfilExterno,
        enCache: [
          lead('propio-1'),
          lead('propio-2', empresa: 'Acme'),
        ],
      );

      // Null pinta "—" en el hub: mejor que un 0 o un total recortado.
      expect(container.read(leadsResumenLocalProvider(eventoId)), isNull);
    },
  );

  test('quien ve todos los leads sí puede contar desde la caché', () async {
    final container = await contenedor(
      perfil: perfilAdmin,
      enCache: [
        lead('a', empresa: 'Acme'),
        lead('b'),
      ],
    );

    final resumen = container.read(leadsResumenLocalProvider(eventoId));

    expect(resumen?.total, 2);
    expect(resumen?.empresas, 1);
  });

  test('el usuario interno también cuenta desde la caché completa', () async {
    final container = await contenedor(
      perfil: perfilUser,
      enCache: [
        lead('propio', empresa: 'Acme'),
        lead('ajeno', empresa: 'Globex'),
      ],
    );

    final resumen = container.read(leadsResumenLocalProvider(eventoId));

    expect(resumen?.total, 2);
    expect(resumen?.empresas, 2);
  });
}
