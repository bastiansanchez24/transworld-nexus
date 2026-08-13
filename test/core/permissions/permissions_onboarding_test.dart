import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transworld_nexus/core/permissions/permissions_onboarding.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('separa permisos base de la etapa de notificaciones', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final onboarding = PermissionsOnboarding(preferences);

    expect(onboarding.yaSolicitados('externo-1'), isFalse);
    expect(onboarding.notificacionesYaSolicitadas('externo-1'), isFalse);

    await onboarding.marcarSolicitados('externo-1');

    expect(onboarding.yaSolicitados('externo-1'), isTrue);
    expect(
      onboarding.notificacionesYaSolicitadas('externo-1'),
      isFalse,
      reason: 'al convertirse a interno aún debe recibir ese prompt',
    );

    await onboarding.marcarNotificacionesSolicitadas('externo-1');
    expect(onboarding.notificacionesYaSolicitadas('externo-1'), isTrue);
  });

  test('la clave legacy de permisos base conserva compatibilidad', () async {
    SharedPreferences.setMockInitialValues({
      'permissions_requested_usuario-legacy': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final onboarding = PermissionsOnboarding(preferences);

    expect(onboarding.yaSolicitados('usuario-legacy'), isTrue);
    expect(onboarding.notificacionesYaSolicitadas('usuario-legacy'), isFalse);
  });
}
