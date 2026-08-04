import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/offline/sync_queue_service.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../permissions/app_permissions.dart';
import '../permissions/permissions_onboarding.dart';

final permissionsOnboardingProvider = Provider<PermissionsOnboarding>((ref) {
  return PermissionsOnboarding(ref.watch(sharedPreferencesProvider));
});

/// Dispara la solicitud de permisos runtime al montarse (post-login /
/// sesión restaurada), una sola vez por usuario en este dispositivo.
/// Envuelve pantallas autenticadas.
class PermissionsBootstrap extends ConsumerStatefulWidget {
  const PermissionsBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PermissionsBootstrap> createState() =>
      _PermissionsBootstrapState();
}

class _PermissionsBootstrapState extends ConsumerState<PermissionsBootstrap> {
  String? _ultimoUsuarioProcesado;
  ProviderSubscription<AsyncValue<AuthState>>? _authSub;

  Future<void> _solicitarSiCorresponde(String userId) async {
    if (_ultimoUsuarioProcesado == userId) return;
    _ultimoUsuarioProcesado = userId;

    final onboarding = ref.read(permissionsOnboardingProvider);
    if (onboarding.yaSolicitados(userId)) return;

    await AppPermissions.requestAll();
    await onboarding.marcarSolicitados(userId);
  }

  void _manejarAuth(AsyncValue<AuthState> next) {
    final userId = next.valueOrNull?.session?.user.id;
    if (userId == null) {
      _ultimoUsuarioProcesado = null;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _solicitarSiCorresponde(userId);
    });
  }

  @override
  void initState() {
    super.initState();
    // listenManual + fireImmediately: una sola suscripción (sesión actual y
    // cambios). ref.listen en build es seguro en Riverpod, pero el patrón
    // anterior combinaba listen + chequeo síncrono y podía pedir permisos dos veces.
    _authSub = ref.listenManual(
      authStateChangesProvider,
      (_, next) => _manejarAuth(next),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _authSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
