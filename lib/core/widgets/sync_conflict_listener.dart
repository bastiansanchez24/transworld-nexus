import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/offline/pending_photo_store.dart';
import '../../data/offline/sync_queue_item.dart';
import '../../data/offline/sync_queue_service.dart';
import '../theme/app_theme.dart';
import 'tw_components.dart';
import 'tw_toast.dart';

/// Escucha conflictos terminales durante toda la sesión y presenta una sola
/// alerta por ítem. Los conflictos permanecen en la bandeja hasta descartarse.
class SyncConflictListener extends ConsumerStatefulWidget {
  const SyncConflictListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncConflictListener> createState() =>
      _SyncConflictListenerState();
}

class _SyncConflictListenerState extends ConsumerState<SyncConflictListener> {
  String? _alertItemId;
  bool _showTray = false;

  /// Capturas que la cola omitió por estar ya en el servidor.
  ///
  /// Un duplicado no necesita decisión del usuario —el dato existe— así que se
  /// avisa con un toast y la fila de entrada no se detiene. Solo los
  /// conflictos que sí exigen resolver siguen abriendo la hoja modal.
  void _avisarDescartes() {
    final descartes = ref.watch(syncDescartesProvider);
    if (descartes.isEmpty) return;

    final mensaje = descartes.length == 1
        ? descartes.single
        : '${descartes.length} capturas ya estaban registradas y se omitieron.';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(syncQueueServiceProvider.notifier).limpiarDescartes();
      TwToast.info(context, mensaje);
    });
  }

  @override
  Widget build(BuildContext context) {
    _avisarDescartes();
    final conflicts = ref.watch(syncConflictsProvider);
    final alert = conflicts
        .where((item) => !item.conflictNotified)
        .cast<SyncQueueItem?>()
        .firstOrNull;

    if (_alertItemId == null && !_showTray && alert != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _alertItemId == null && !_showTray) {
          setState(() => _alertItemId = alert.id);
        }
      });
    }

    final current = conflicts
        .where((item) => item.id == _alertItemId)
        .cast<SyncQueueItem?>()
        .firstOrNull;

    // Un cambio de sesión reemplaza el namespace de la cola. Si el conflicto
    // visible pertenecía a la cuenta anterior, liberar el id para que una
    // cuenta nueva pueda mostrar sus propias alertas.
    if (_alertItemId != null && current == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _alertItemId != null &&
            !ref
                .read(syncConflictsProvider)
                .any((item) => item.id == _alertItemId)) {
          setState(() => _alertItemId = null);
        }
      });
    }

    return Stack(
      children: [
        widget.child,
        if (current != null) ...[
          const Positioned.fill(
            child: ModalBarrier(dismissible: false, color: Color(0x73000000)),
          ),
          Positioned.fill(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AlertDialog(
                  title: const Text('Lead no sincronizado'),
                  content: Text(
                    current.conflict?.message ??
                        'Hay un conflicto que requiere revisión.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => _closeAlert(current.id),
                      child: const Text('Ahora no'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        await ref
                            .read(syncQueueServiceProvider.notifier)
                            .markConflictNotified(current.id);
                        if (mounted) {
                          setState(() {
                            _alertItemId = null;
                            _showTray = true;
                          });
                        }
                      },
                      child: const Text('Revisar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (_showTray)
          Positioned.fill(
            child: Material(
              color: AppColors.background,
              child: SafeArea(
                child: SyncConflictsTray(
                  onClose: () => setState(() => _showTray = false),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _closeAlert(String itemId) async {
    await ref
        .read(syncQueueServiceProvider.notifier)
        .markConflictNotified(itemId);
    if (mounted) setState(() => _alertItemId = null);
  }
}

Future<void> showSyncConflictsSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: .82,
      child: SyncConflictsTray(),
    ),
  );
}

class SyncConflictsTray extends ConsumerWidget {
  const SyncConflictsTray({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflicts = ref.watch(syncConflictsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Conflictos de sincronización',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              TwIconButton(
                icon: Symbols.close_rounded,
                iconSize: 20,
                tooltip: 'Cerrar',
                onTap: onClose ?? () => Navigator.maybePop(context),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Estos leads no se volverán a enviar automáticamente.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: conflicts.isEmpty
              ? const Center(child: Text('No hay conflictos pendientes.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: conflicts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = conflicts[index];
                    final conflict = item.conflict;
                    final leadName = item.payload['nombre_completo']
                        ?.toString()
                        .trim();
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (leadName != null && leadName.isNotEmpty)
                              Text(
                                leadName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              conflict?.message ??
                                  item.lastError ??
                                  'Conflicto sin detalle.',
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _discard(ref, item),
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('Descartar copia local'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _discard(WidgetRef ref, SyncQueueItem item) async {
    final store = ref.read(pendingPhotoStoreProvider);
    for (final marker in _localPhotos(item.payload)) {
      await store.borrar(marker);
    }
    await ref.read(syncQueueServiceProvider.notifier).discardConflict(item.id);
  }

  Iterable<String> _localPhotos(Map<String, dynamic> payload) sync* {
    final direct = payload['fotos_urls'];
    if (direct is List) {
      yield* direct.map((e) => e.toString()).where(esFotoLocal);
    }
    final changes = payload['changes'];
    if (changes is Map) {
      final nested = changes['fotos_urls'];
      if (nested is List) {
        yield* nested.map((e) => e.toString()).where(esFotoLocal);
      }
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
