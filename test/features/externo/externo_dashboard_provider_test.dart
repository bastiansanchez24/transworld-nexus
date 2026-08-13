import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/constants/supabase_tables.dart';
import 'package:transworld_nexus/data/offline/sync_queue_item.dart';
import 'package:transworld_nexus/features/externo/providers/externo_dashboard_provider.dart';

void main() {
  const perfilId = 'perfil-externo';
  final now = DateTime(2026, 8, 12);

  SyncQueueItem item({
    required String id,
    SyncOperation operation = SyncOperation.insert,
    SyncStatus status = SyncStatus.pending,
    String table = SupabaseTables.leads,
    String? owner = perfilId,
    String? serverLeadId,
  }) {
    return SyncQueueItem(
      id: id,
      operation: operation,
      table: table,
      payload: {
        'id': id,
        'perfil_id': ?owner,
        '_server_lead_id': ?serverLeadId,
      },
      createdAt: now,
      updatedAt: now,
      status: status,
    );
  }

  test('cuenta solo inserts de leads pendientes del perfil externo', () {
    final items = [
      item(id: 'pending'),
      item(id: 'failed', status: SyncStatus.failed),
      item(id: 'other-owner', owner: 'otro-perfil'),
      item(id: 'other-table', table: SupabaseTables.registrados),
      item(id: 'update', operation: SyncOperation.update),
    ];

    expect(contarLeadsPendientesPorPerfil(items, perfilId), 2);
  });

  test('excluye syncing y synced para evitar doble conteo remoto', () {
    final items = [
      item(id: 'syncing', status: SyncStatus.syncing),
      item(id: 'synced', status: SyncStatus.synced),
      item(id: 'without-owner', owner: null),
    ];

    expect(contarLeadsPendientesPorPerfil(items, perfilId), 0);
  });

  test('no duplica un insert cuya fila ya fue creada en el servidor', () {
    final items = [
      item(
        id: 'foto-fallida',
        status: SyncStatus.failed,
        serverLeadId: 'lead-remoto',
      ),
      item(id: 'solo-local', status: SyncStatus.failed),
    ];

    expect(contarLeadsPendientesPorPerfil(items, perfilId), 1);
  });

  test('cuenta el evento asignado legado sin duplicar autorizaciones', () {
    expect(
      contarEventosConAcceso(const [
        'evento-a',
        'evento-b',
      ], eventoAsignadoId: 'evento-a'),
      2,
    );
    expect(
      contarEventosConAcceso(const [], eventoAsignadoId: 'evento-legado'),
      1,
    );
    expect(contarEventosConAcceso(const [], eventoAsignadoId: '  '), 0);
  });
}
