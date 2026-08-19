import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../core/network/offline_policy.dart';
import '../../../core/theme/tw_tokens.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/tw_components.dart';
import '../../../core/widgets/tw_toast.dart';
import '../../../data/offline/snapshot_service.dart';
import '../../../data/offline/sync_coordinator.dart';
import '../../../data/offline/sync_queue_item.dart';
import '../../../data/offline/sync_queue_service.dart';
import '../../../core/constants/supabase_tables.dart';

/// Estado del modo offline: qué hay pendiente de subir, cuándo fue la última
/// bajada completa y un botón para forzar ambas cosas.
class SincronizacionScreen extends ConsumerWidget {
  const SincronizacionScreen({super.key});

  static String _formatearFecha(DateTime fecha) {
    return DateFormat("d 'de' MMMM, HH:mm", 'es').format(fecha);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(snapshotServiceProvider.notifier).restaurarMetadatosSiHaceFalta();
    final snapshot = ref.watch(snapshotServiceProvider);
    final cola = ref.watch(syncQueueServiceProvider);
    final hayRed = ref.watch(isOnlineProvider);

    final pendientes = cola.where(
      (i) =>
          i.status == SyncStatus.pending ||
          i.status == SyncStatus.syncing ||
          i.status == SyncStatus.failed,
    );
    final leadsPendientes = pendientes
        .where((i) => i.table == SupabaseTables.leads)
        .length;
    final acreditacionesPendientes = pendientes
        .where((i) => i.table == SupabaseTables.registrados)
        .length;

    return AppScaffold(
      title: 'Sincronización',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _Estado(hayRed: hayRed, snapshot: snapshot),
          const TwSectionLabel('Pendientes de subir'),
          _Contador(
            icono: Symbols.person_search_rounded,
            etiqueta: 'Leads capturados',
            valor: leadsPendientes,
          ),
          const SizedBox(height: 10),
          _Contador(
            icono: Symbols.how_to_reg_rounded,
            etiqueta: 'Acreditaciones',
            valor: acreditacionesPendientes,
          ),
          if (snapshot.errores.isNotEmpty) ...[
            const TwSectionLabel('Incidencias de la última bajada'),
            for (final error in snapshot.errores)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Symbols.error_rounded,
                      size: 18,
                      color: TwColors.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(error, style: TwText.errorText)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: snapshot.enCurso || !hayRed
                ? null
                : () async {
                    // Primero se sube lo capturado y después se vuelve a bajar:
                    // al revés, el snapshot pisaría con datos del servidor unas
                    // listas a las que aún les falta lo local.
                    await ref.read(syncCoordinatorProvider).sincronizarAhora();
                    await ref.read(snapshotServiceProvider.notifier).ejecutar();
                    if (!context.mounted) return;
                    TwToast.info(context, 'Sincronización completada.');
                  },
            icon: snapshot.enCurso
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Symbols.sync_rounded),
            label: Text(
              snapshot.enCurso ? 'Sincronizando…' : 'Sincronizar ahora',
            ),
          ),
          if (!hayRed)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Necesitas conexión para sincronizar. Lo capturado se sube '
                'solo en cuanto vuelva la red.',
                style: TwText.tileSubtitle,
                textAlign: TextAlign.center,
              ),
            ),
          if (!supportsOfflineCacheAqui)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Esta plataforma trabaja siempre en línea: no guarda una copia '
                'local de los eventos.',
                style: TwText.tileSubtitle,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _Estado extends StatelessWidget {
  const _Estado({required this.hayRed, required this.snapshot});

  final bool hayRed;
  final SnapshotEstado snapshot;

  @override
  Widget build(BuildContext context) {
    final ultimo = snapshot.ultimoExito;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hayRed ? TwColors.greenTint : TwColors.dangerTint,
        borderRadius: TwRadii.field,
      ),
      child: Row(
        children: [
          Icon(
            hayRed ? Symbols.cloud_done_rounded : Symbols.cloud_off_rounded,
            color: hayRed ? TwColors.greenInk : TwColors.danger,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hayRed ? 'Conectado' : 'Sin conexión',
                  style: TwText.tileTitle,
                ),
                const SizedBox(height: 2),
                Text(
                  ultimo == null
                      ? 'Todavía no se ha descargado una copia local.'
                      : 'Última descarga: '
                            '${SincronizacionScreen._formatearFecha(ultimo)}',
                  style: TwText.tileSubtitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final int valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 20, color: TwColors.muted),
        const SizedBox(width: 10),
        Expanded(child: Text(etiqueta, style: TwText.tileTitle)),
        Text(
          '$valor',
          style: TwText.tileTitle.copyWith(
            color: valor > 0 ? TwColors.brand700 : TwColors.muted,
          ),
        ),
      ],
    );
  }
}
