import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/supabase_tables.dart';
import '../../core/network/connectivity_service.dart';
import '../repositories/leads_repository.dart';
import '../repositories/registrados_repository.dart';
import 'sync_queue_service.dart';

/// Punto único donde se registran los [SyncExecutor] de cada dominio y se
/// dispara `processPending()` automáticamente al recuperar conexión.
///
/// Esto reemplaza los múltiples listeners sueltos que había en el proyecto
/// legado (`_layout.tsx`, `index.tsx`, `usar-app.tsx`, `ver-registrados.tsx`
/// llamaban `procesarColaOffline()` cada uno por su cuenta, apuntando a una
/// cola que además tenía el bug de la clave equivocada — ver Sección 17.3).
/// Acá hay un solo listener de conectividad para toda la app.
class SyncCoordinator {
  SyncCoordinator(this._ref) {
    _ref.listen<AsyncValue<bool>>(connectivityStreamProvider, (previous, next) {
      final wasOffline = previous?.valueOrNull == false;
      final isOnlineNow = next.valueOrNull == true;
      if (wasOffline && isOnlineNow) {
        sincronizarAhora();
      }
    });
  }

  final Ref _ref;

  Map<String, SyncExecutor> get _executors => {
        SupabaseTables.registrados: _ref.read(registradosRepositoryProvider),
        SupabaseTables.leads: _ref.read(leadsRepositoryProvider),
      };

  Future<int> sincronizarAhora() async {
    final queue = _ref.read(syncQueueServiceProvider.notifier);
    try {
      final synced = await queue.processPending(_executors);
      if (synced > 0) {
        developer.log('Sincronizados $synced ítems pendientes.',
            name: 'SyncCoordinator');
      }
      return synced;
    } catch (e) {
      developer.log('Error sincronizando cola offline: $e',
          name: 'SyncCoordinator');
      return 0;
    }
  }
}

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  return SyncCoordinator(ref);
});

/// Debe leerse una vez, cerca de la raíz del árbol de widgets (ver
/// `app.dart`), para que el listener de conectividad quede activo durante
/// toda la vida de la app.
final syncCoordinatorInitializerProvider = Provider<void>((ref) {
  ref.watch(syncCoordinatorProvider);
});
