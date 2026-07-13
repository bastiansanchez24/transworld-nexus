import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adaptador estándar para que `go_router` pueda re-evaluar sus redirects
/// cada vez que un `Stream` emite (en este caso, los cambios de sesión de
/// Supabase). Patrón recomendado por la documentación de `go_router`.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  /// Fuerza una re-evaluación de los redirects sin esperar al stream (usado
  /// cuando cambia el perfil de negocio, ej. `cambiar_pass`).
  void refresh() => notifyListeners();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
