import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../network/connectivity_service.dart';
import '../network/offline_policy.dart';
import '../theme/tw_tokens.dart';

/// Tapa la app cuando no hay Internet en las plataformas que no tienen modo
/// offline (Windows, macOS y web).
///
/// Ahí no se baja el snapshot ni existe caché operativa: dejar navegar produce
/// listas vacías y formularios cuyas escrituras se pierden. En iOS y Android
/// no aparece nunca —esas sí operan con disco— y tampoco cubre login ni
/// recuperar contraseña, que deben seguir visibles.
class OfflineBlockingOverlay extends ConsumerWidget {
  const OfflineBlockingOverlay({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!blocksUiWhenOfflineAqui) return child;

    // Optimista mientras se resuelve el primer intento: si no, el overlay
    // parpadea en cada arranque.
    final hayRed = ref.watch(conexionRealProvider).valueOrNull ?? true;
    if (hayRed) return child;

    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) {
        final location = router.routerDelegate.currentConfiguration.uri.path;
        if (OfflinePolicy.isAuthGateRoute(location)) return child;
        return Stack(
          children: [
            child,
            const Positioned.fill(child: _AvisoSinConexion()),
          ],
        );
      },
    );
  }
}

class _AvisoSinConexion extends StatelessWidget {
  const _AvisoSinConexion();

  @override
  Widget build(BuildContext context) {
    // `AbsorbPointer` deja la app de abajo intacta pero inalcanzable: no se
    // navega ni se pulsa nada mientras dure el corte.
    return AbsorbPointer(
      child: Material(
        color: TwColors.bg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Symbols.wifi_off_rounded,
                  size: 56,
                  color: TwColors.danger,
                ),
                const SizedBox(height: 18),
                Text(
                  'Sin conexión',
                  style: TwText.heroTitle.copyWith(color: TwColors.ink),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Revisa tu conexión a Internet para seguir usando RegisPro.',
                  style: TwText.tileSubtitle,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
