import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/perfil.dart';
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
  String? _procesoEnCursoPara;
  ProviderSubscription<AsyncValue<AuthState>>? _authSub;
  ProviderSubscription<AsyncValue<Perfil?>>? _perfilSub;

  Future<void> _solicitarSiCorresponde(String userId) async {
    if (_procesoEnCursoPara == userId) return;
    _procesoEnCursoPara = userId;

    final onboarding = ref.read(permissionsOnboardingProvider);

    try {
      // Fail closed mientras el perfil está cargando: no pedir el permiso de
      // notificaciones hasta conocer la capacidad real de esta sesión.
      final perfil = await ref.read(currentPerfilProvider.future);
      if (perfil == null || perfil.id != userId) {
        return;
      }

      if (!onboarding.yaSolicitados(userId)) {
        await AppPermissions.requestAll(
          includeNotifications: false,
          includeAppUpdates: false,
        );

        if (perfil.canAccessNotifications) {
          await AppPermissions.requestNotifications();
          await onboarding.marcarNotificacionesSolicitadas(userId);
        }

        if (perfil.canAccessAppUpdates) {
          await AppPermissions.requestInstallPackages();
        }

        await onboarding.marcarSolicitados(userId);
      } else if (perfil.canAccessNotifications &&
          !onboarding.notificacionesYaSolicitadas(userId)) {
        await AppPermissions.requestNotifications();
        await onboarding.marcarNotificacionesSolicitadas(userId);
      }
    } catch (_) {
      // Reintentar en la próxima emisión de sesión/perfil o próximo montaje.
    } finally {
      if (_procesoEnCursoPara == userId) _procesoEnCursoPara = null;
    }
  }

  void _manejarAuth(AsyncValue<AuthState> next) {
    final userId = next.valueOrNull?.session?.user.id;
    if (userId == null) {
      _procesoEnCursoPara = null;
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
    _perfilSub = ref.listenManual(currentPerfilProvider, (_, next) {
      final perfil = next.valueOrNull;
      if (perfil == null) return;
      _solicitarSiCorresponde(perfil.id);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _authSub?.close();
    _perfilSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
