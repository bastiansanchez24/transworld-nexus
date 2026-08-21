import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/constants/app_role.dart';
import 'package:transworld_nexus/core/constants/supabase_tables.dart';
import 'package:transworld_nexus/data/models/evento_lead.dart';
import 'package:transworld_nexus/data/models/lead.dart';
import 'package:transworld_nexus/data/models/perfil.dart';
import 'package:transworld_nexus/data/offline/sync_queue_item.dart';
import 'package:transworld_nexus/features/capturador/providers/capturador_providers.dart';

void main() {
  group('filtrarActividadesCapturaAutorizadas', () {
    final fecha = DateTime(2026, 8, 21);
    late List<EventoLead> actividades;

    setUp(() {
      actividades = [
        EventoLead(
          id: 'campana-autorizada',
          nombre: 'Evento autorizado',
          fecha: fecha,
          eventoOrigenId: 'evento-1',
          tipo: TipoEventoLead.interno,
        ),
        EventoLead(
          id: 'campana-ajena',
          nombre: 'Evento ajeno',
          fecha: fecha,
          eventoOrigenId: 'evento-2',
          tipo: TipoEventoLead.interno,
        ),
        EventoLead(
          id: 'campana-sin-origen',
          nombre: 'Evento autorizado',
          fecha: fecha,
        ),
      ];
    });

    Perfil perfil(AppRole rol) =>
        Perfil(id: 'usuario-1', nombreCompleto: 'Usuario', rol: rol);

    test('user ve externas y solo internas de eventos asignados', () {
      final visibles = filtrarActividadesCapturaAutorizadas(
        perfil: perfil(AppRole.user),
        eventosAutorizados: const {'evento-1'},
        actividades: actividades,
      );

      expect(visibles.map((actividad) => actividad.id), [
        'campana-autorizada',
        'campana-sin-origen',
      ]);
    });

    test('externo ve externas y no autoriza internas por nombre', () {
      final visibles = filtrarActividadesCapturaAutorizadas(
        perfil: perfil(AppRole.externo),
        eventosAutorizados: const {'evento-1'},
        actividades: actividades,
      );

      expect(visibles.map((actividad) => actividad.id), [
        'campana-autorizada',
        'campana-sin-origen',
      ]);
      expect(
        visibles.any((actividad) => actividad.eventoOrigenId == null),
        isTrue,
      );
    });

    test('sin eventos asignados aún conserva las actividades externas', () {
      final visibles = filtrarActividadesCapturaAutorizadas(
        perfil: perfil(AppRole.user),
        eventosAutorizados: const {},
        actividades: actividades,
      );

      expect(visibles.map((actividad) => actividad.id), ['campana-sin-origen']);
    });

    test('admin y organizador conservan alcance global', () {
      for (final rol in [AppRole.admin, AppRole.organizador]) {
        final visibles = filtrarActividadesCapturaAutorizadas(
          perfil: perfil(rol),
          eventosAutorizados: const {},
          actividades: actividades,
        );
        expect(visibles, hasLength(3));
      }
    });

    test('sin perfil falla cerrado', () {
      expect(
        filtrarActividadesCapturaAutorizadas(
          perfil: null,
          eventosAutorizados: const {'evento-1'},
          actividades: actividades,
        ),
        isEmpty,
      );
    });
  });

  test('un duplicado en conflicto no aparece como lead pendiente válido', () {
    final now = DateTime.utc(2026, 8, 12);
    SyncQueueItem item(String id, SyncStatus status) => SyncQueueItem(
      id: id,
      operation: SyncOperation.insert,
      table: 'leads',
      payload: const {'evento_id': 'evento-1', 'nombre_completo': 'Lead'},
      createdAt: now,
      updatedAt: now,
      status: status,
    );

    final visible = leadQueueItemsForOverlay([
      item('pending', SyncStatus.pending),
      item('failed', SyncStatus.failed),
      item('conflict', SyncStatus.conflict),
      item('synced', SyncStatus.synced),
    ]).map((item) => item.id);

    expect(visible, ['pending', 'failed']);
  });

  test('fusionarLeadsConCola aplica inserts y updates pendientes', () {
    final now = DateTime.utc(2026, 8, 13);
    const eventoId = 'evento-1';
    final servidor = [
      const Lead(
        id: 'lead-1',
        eventoId: eventoId,
        nombreCompleto: 'Ana',
        empresa: 'Acme',
      ),
    ];
    final cola = [
      SyncQueueItem(
        id: 'nuevo',
        operation: SyncOperation.insert,
        table: SupabaseTables.leads,
        payload: const {'evento_id': eventoId, 'nombre_completo': 'Bruno'},
        createdAt: now,
        updatedAt: now,
      ),
      SyncQueueItem(
        id: 'upd',
        operation: SyncOperation.update,
        table: SupabaseTables.leads,
        payload: const {
          'id': 'lead-1',
          'changes': {'nombre_completo': 'Ana Pérez'},
        },
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final fusionados = fusionarLeadsConCola(
      servidor: servidor,
      colaDeLeads: cola,
      eventoId: eventoId,
    );

    expect(fusionados.map((l) => l.nombreCompleto), ['Bruno', 'Ana Pérez']);
    expect(fusionados.first.pendienteDeSincronizar, isTrue);
  });

  test('resumenDesdeLeads cuenta leads con empresa informada', () {
    const eventoId = 'evento-1';
    final resumen = resumenDesdeLeads([
      const Lead(
        id: '1',
        eventoId: eventoId,
        nombreCompleto: 'Ana',
        empresa: 'Acme',
      ),
      const Lead(id: '2', eventoId: eventoId, nombreCompleto: 'Bruno'),
      const Lead(
        id: '3',
        eventoId: eventoId,
        nombreCompleto: 'Carla',
        empresa: '  ',
      ),
    ]);

    expect(resumen.total, 3);
    expect(resumen.empresas, 1);
  });

  test('aplicarColaAResumen suma inserts pendientes de la campaña', () {
    final now = DateTime.utc(2026, 8, 13);
    const eventoId = 'evento-1';
    final cola = [
      SyncQueueItem(
        id: 'nuevo',
        operation: SyncOperation.insert,
        table: SupabaseTables.leads,
        payload: const {
          'evento_id': eventoId,
          'nombre_completo': 'Bruno',
          'empresa': 'Nexus',
        },
        createdAt: now,
        updatedAt: now,
      ),
      SyncQueueItem(
        id: 'otra',
        operation: SyncOperation.insert,
        table: SupabaseTables.leads,
        payload: const {
          'evento_id': 'otra-campana',
          'nombre_completo': 'Dana',
          'empresa': 'Otra',
        },
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final resumen = aplicarColaAResumen(
      base: const LeadsResumen(total: 10, empresas: 4),
      cola: cola,
      eventoId: eventoId,
    );

    expect(resumen.total, 11);
    expect(resumen.empresas, 5);
  });

  test('LeadsResumen.fromMap acepta enteros y numéricos de PostgREST', () {
    final resumen = LeadsResumen.fromMap(const {'total': 12, 'empresas': 5.0});
    expect(resumen.total, 12);
    expect(resumen.empresas, 5);
  });
}
