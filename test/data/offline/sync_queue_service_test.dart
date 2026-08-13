import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transworld_nexus/data/offline/sync_queue_item.dart';
import 'package:transworld_nexus/data/offline/sync_queue_service.dart';

class _ConflictExecutor implements SyncExecutor {
  int calls = 0;

  @override
  String get table => 'leads';

  @override
  Future<void> onInsert(Map<String, dynamic> payload) async {
    calls++;
    throw const TerminalSyncConflictException(
      SyncConflict(
        code: 'lead_duplicate_other',
        message: 'Este lead ya fue registrado por Ana Pérez',
        primerCapturadorNombre: 'Ana Pérez',
      ),
    );
  }

  @override
  Future<void> onUpdate(Map<String, dynamic> payload) => onInsert(payload);
}

class _BlockingExecutor implements SyncExecutor {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  String get table => 'leads';

  @override
  Future<void> onInsert(Map<String, dynamic> payload) async {
    started.complete();
    await release.future;
  }

  @override
  Future<void> onUpdate(Map<String, dynamic> payload) => onInsert(payload);
}

void main() {
  group('esIdSoloLocal', () {
    test('reconoce el id temporal de un insert encolado', () {
      expect(esIdSoloLocal('${syncLocalIdPrefix}abc-123'), isTrue);
    });

    test('un uuid del servidor no es local', () {
      expect(esIdSoloLocal('a1b2c3d4-e5f6-7890-abcd-ef1234567890'), isFalse);
    });

    test('no confunde un uuid que contenga "local" más adelante', () {
      expect(esIdSoloLocal('abc-local_123'), isFalse);
    });
  });

  group('SyncQueueService por usuario', () {
    test('cambiar de cuenta no expone ni procesa la cola anterior', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final queueA = SyncQueueService(prefs, 'usuario-a');
      await queueA.enqueueInsert(
        table: 'leads',
        payload: {'perfil_id': 'usuario-a'},
      );

      final queueB = SyncQueueService(prefs, 'usuario-b');
      expect(queueB.state, isEmpty);
      final restoredA = SyncQueueService(prefs, 'usuario-a');
      expect(restoredA.state, hasLength(1));
    });

    test('un conflicto es terminal y conserva datos estructurados', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final queue = SyncQueueService(prefs, 'usuario-a');
      await queue.enqueueInsert(
        table: 'leads',
        payload: {'perfil_id': 'usuario-a'},
      );
      final executor = _ConflictExecutor();

      await queue.processPending({'leads': executor});
      expect(queue.state.single.status, SyncStatus.conflict);
      expect(queue.state.single.conflict?.primerCapturadorNombre, 'Ana Pérez');
      expect(queue.pendingFor('leads'), isEmpty);

      await queue.processPending({'leads': executor});
      expect(executor.calls, 1, reason: 'no debe reintentar conflictos');

      final discarded = await queue.discardConflict(queue.state.single.id);
      expect(discarded?.conflict?.primerCapturadorNombre, 'Ana Pérez');
      expect(queue.state, isEmpty);
    });

    test(
      'no pierde una edición mientras el insert está sincronizando',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final queue = SyncQueueService(prefs, 'usuario-a');
        final localId = await queue.enqueueInsert(
          table: 'leads',
          payload: {'perfil_id': 'usuario-a', 'nombre_completo': 'Original'},
        );
        final executor = _BlockingExecutor();

        final processing = queue.processPending({'leads': executor});
        await executor.started.future;

        await expectLater(
          queue.enqueueUpdate(
            table: 'leads',
            entityId: localId,
            changes: {'nombre_completo': 'Editado'},
          ),
          throwsA(isA<SyncItemInFlightException>()),
        );

        executor.release.complete();
        expect(await processing, 1);
        expect(queue.state, isEmpty);
      },
    );

    test(
      'legacy inequívoco se adopta y el resto queda en cuarentena',
      () async {
        final now = DateTime.utc(2026, 8, 12);
        final propio = SyncQueueItem(
          id: 'propio',
          operation: SyncOperation.insert,
          table: 'leads',
          payload: const {'perfil_id': 'usuario-a'},
          createdAt: now,
          updatedAt: now,
        );
        final ambiguo = SyncQueueItem(
          id: 'ambiguo',
          operation: SyncOperation.insert,
          table: 'registrados',
          payload: const {},
          createdAt: now,
          updatedAt: now,
        );
        SharedPreferences.setMockInitialValues({
          'sync_queue_v1': jsonEncode([propio.toJson(), ambiguo.toJson()]),
        });
        final prefs = await SharedPreferences.getInstance();
        final queue = SyncQueueService(prefs, 'usuario-a');

        expect(await queue.migrateLegacyIfUnambiguous(), 1);
        expect(queue.state.single.id, 'propio');
        expect(
          prefs.getString('sync_queue_v2_quarantine'),
          contains('ambiguo'),
        );
        expect(prefs.getString('sync_queue_v1'), isNull);
      },
    );
  });
}
