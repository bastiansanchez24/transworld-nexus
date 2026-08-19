import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/offline/sync_queue_service.dart';
import '../../data/offline/sync_coordinator.dart';
import '../network/connectivity_service.dart';
import '../theme/app_theme.dart';
import 'sync_conflict_listener.dart';

/// `true` cuando el banner tiene algo que decir (sin conexión, pendientes o
/// conflictos).
///
/// Vive fuera del widget porque [OfflineBannerHost] necesita saberlo *antes*
/// de construirlo: solo cuando el banner ocupa sitio hay que reasignar el
/// inset de la barra de estado.
final offlineBannerVisibleProvider = Provider<bool>((ref) {
  final isOnline = ref.watch(isOnlineProvider);
  final pending = ref.watch(pendingSyncCountProvider);
  final conflicts = ref.watch(syncConflictsProvider).length;
  return !isOnline || pending > 0 || conflicts > 0;
});

/// Indicador visible de "modo local" + cantidad de operaciones pendientes
/// por sincronizar. En el proyecto legado este indicador vivía copiado y
/// levemente distinto en cada pantalla; acá es un solo widget reutilizable
/// que además refleja el estado real de la cola unificada (ver
/// data/offline/sync_queue_service.dart).
///
/// Se pinta debajo de la barra de estado: es el primer elemento de la pantalla
/// y sin ese inset quedaba tapando la hora del sistema. Colocarlo con
/// [OfflineBannerHost] evita además que la cabecera de abajo vuelva a reservar
/// el mismo espacio.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final pending = ref.watch(pendingSyncCountProvider);
    final conflicts = ref.watch(syncConflictsProvider).length;

    if (isOnline && pending == 0 && conflicts == 0) {
      return const SizedBox.shrink();
    }

    final texto = conflicts > 0
        ? '$conflicts conflicto(s) de sincronización · Revisar'
        : !isOnline
        ? (pending > 0
              ? 'Sin conexión · $pending pendiente(s)'
              : 'Sin conexión')
        : '$pending pendiente(s) · Reintentar';

    return Material(
      color: conflicts > 0
          ? AppColors.dangerTint
          : !isOnline
          ? AppColors.dangerTint
          : AppColors.successTint,
      child: InkWell(
        onTap: conflicts > 0
            ? () => showSyncConflictsSheet(context, ref)
            : isOnline && pending > 0
            ? () => ref.read(syncCoordinatorProvider).sincronizarAhora()
            : null,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            12,
            MediaQuery.paddingOf(context).top + 6,
            12,
            6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                conflicts > 0
                    ? Icons.warning_amber_rounded
                    : !isOnline
                    ? Icons.cloud_off_rounded
                    : Icons.cloud_upload_rounded,
                size: 16,
                color: conflicts > 0 || !isOnline
                    ? AppColors.danger
                    : AppColors.success,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  texto,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: conflicts > 0 || !isOnline
                        ? AppColors.danger
                        : AppColors.primaryDeep,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Coloca el banner arriba de una pantalla y resuelve la barra de estado una
/// sola vez.
///
/// Sin esto el inset superior se contaba dos veces: el banner se pintaba desde
/// `y = 0` (encima del reloj) y la cabecera de abajo seguía reservando su
/// propio hueco del alto de la barra de estado. Cuando el banner es visible él
/// se queda con el inset y [builder] lo recibe ya consumido; cuando no lo es,
/// [builder] ve la pantalla intacta.
class OfflineBannerHost extends ConsumerWidget {
  const OfflineBannerHost({
    super.key,
    required this.builder,
    this.banner = const OfflineBanner(),
  });

  /// El contenido de la pantalla. Es un builder —y no un `Widget`— para que
  /// pueda leer el `MediaQuery` corregido: varias cabeceras calculan su alto a
  /// partir del inset superior.
  final WidgetBuilder builder;

  final Widget banner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(offlineBannerVisibleProvider)) return builder(context);

    return Column(
      children: [
        banner,
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: Builder(builder: builder),
          ),
        ),
      ],
    );
  }
}

/// [Column] que antepone el banner offline resolviendo la barra de estado,
/// para las pantallas que apilan su contenido a mano.
///
/// Sustituye a un `Column` que llevaba `const OfflineBanner()` como primer
/// hijo: ahí el banner se pintaba sobre el reloj y la cabecera de abajo
/// reservaba otra vez el mismo inset. Ver [OfflineBannerHost].
class OfflineBannerColumn extends ConsumerWidget {
  const OfflineBannerColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(offlineBannerVisibleProvider)) {
      return Column(children: children);
    }

    return Column(
      children: [
        const OfflineBanner(),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}
