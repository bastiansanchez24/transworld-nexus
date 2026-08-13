import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/constants/supabase_tables.dart';
import 'package:transworld_nexus/data/models/lead.dart';
import 'package:transworld_nexus/data/offline/sync_queue_item.dart';
import 'package:transworld_nexus/features/capturador/providers/capturador_providers.dart';

void main() {
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
