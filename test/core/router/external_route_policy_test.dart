import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/router/external_route_policy.dart';
import 'package:transworld_nexus/core/router/route_paths.dart';

void main() {
  const eventId = 'evento-autorizado';
  const otherEventId = 'evento-ajeno';
  const campaignId = 'campana-leads';
  const authorized = {eventId};

  bool allowed(
    String location, {
    String? sourceEventId,
    bool trustedScannerContext = false,
  }) {
    return isExternalOperationalRouteAllowed(
      location: location,
      authorizedEventIds: authorized,
      captureSourceEventId: sourceEventId,
      hasTrustedScannerContext: trustedScannerContext,
    );
  }

  test('permite solo dashboard y escáner QR de eventos autorizados', () {
    expect(allowed(RoutePaths.externoEvento(eventId)), isTrue);
    expect(allowed(RoutePaths.acreditarQr(eventId)), isTrue);

    expect(allowed(RoutePaths.externoEvento(otherEventId)), isFalse);
    expect(allowed(RoutePaths.acreditarQr(otherEventId)), isFalse);
  });

  test('captura lead exige origen autorizado y contexto real del escáner', () {
    final location = RoutePaths.capturarLead(campaignId);

    expect(
      allowed(location, sourceEventId: eventId, trustedScannerContext: true),
      isTrue,
    );
    expect(
      allowed(location, sourceEventId: eventId),
      isFalse,
      reason: 'un query desdeEvento falsificable no acredita procedencia',
    );
    expect(
      allowed(
        location,
        sourceEventId: otherEventId,
        trustedScannerContext: true,
      ),
      isFalse,
    );
  });

  test('bloquea registro, notificaciones, estadísticas y shell interno', () {
    final forbidden = <String>[
      RoutePaths.registrar(eventId),
      RoutePaths.registroPorCliente(eventId),
      RoutePaths.notificaciones,
      RoutePaths.perfil,
      RoutePaths.kpi(eventId),
      RoutePaths.verRegistrados(eventId),
      RoutePaths.eventos,
      RoutePaths.capturador,
      RoutePaths.usuarios,
      RoutePaths.registroForms,
      RoutePaths.home,
    ];

    for (final location in forbidden) {
      expect(allowed(location), isFalse, reason: 'debe bloquear $location');
    }
  });

  test('con autorizaciones aún desconocidas la política falla cerrada', () {
    expect(
      isExternalOperationalRouteAllowed(
        location: RoutePaths.notificaciones,
        authorizedEventIds: const {},
      ),
      isFalse,
    );
    expect(
      isExternalOperationalRouteAllowed(
        location: RoutePaths.registrar(eventId),
        authorizedEventIds: const {},
      ),
      isFalse,
    );
  });
}
