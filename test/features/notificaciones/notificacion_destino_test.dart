import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/router/route_paths.dart';
import 'package:transworld_nexus/data/models/notificacion.dart';
import 'package:transworld_nexus/features/notificaciones/notificacion_destino.dart';

NotificacionInbox _inbox(Map<String, dynamic> extra) {
  return NotificacionInbox.fromMap({
    'id': 'n1',
    'titulo': 'Título',
    'cuerpo': 'Cuerpo',
    'nombre_registrado': 'Ada Lovelace',
    'nombre_evento': 'Expo',
    ...extra,
  }, leida: false);
}

void main() {
  group('destinoDeNotificacion', () {
    test('un comentario abre el hilo del lead', () {
      final destino = destinoDeNotificacion(
        _inbox({
          'tipo': 'lead_comentario',
          'lead_id': 'lead-1',
          'evento_lead_id': 'campana-1',
        }),
      );

      expect(destino, RoutePaths.comentariosLead('campana-1', 'lead-1'));
    });

    test('un registro abre el evento', () {
      final destino = destinoDeNotificacion(
        _inbox({'tipo': 'registro', 'evento_id': 'evento-1'}),
      );

      expect(destino, RoutePaths.usarEvento('evento-1'));
    });

    test('un hito de acreditación abre el evento', () {
      final destino = destinoDeNotificacion(
        _inbox({'tipo': 'acreditacion_50', 'evento_id': 'evento-1'}),
      );

      expect(destino, RoutePaths.usarEvento('evento-1'));
    });

    test('sin referencia utilizable no navega a ninguna parte', () {
      // El evento pudo eliminarse: mejor quedarse en el inbox que empujar
      // una ruta con un id nulo.
      expect(destinoDeNotificacion(_inbox({'tipo': 'registro'})), isNull);
      expect(
        destinoDeNotificacion(
          _inbox({'tipo': 'lead_comentario', 'lead_id': 'lead-1'}),
        ),
        isNull,
      );
    });
  });

  group('destinoDeDatosPush', () {
    test('lee el data de FCM, donde todo llega como texto', () {
      final destino = destinoDeDatosPush(const {
        'tipo': 'lead_comentario',
        'lead_id': 'lead-9',
        'evento_lead_id': 'campana-9',
        'evento_id': '',
      });

      expect(destino, RoutePaths.comentariosLead('campana-9', 'lead-9'));
    });

    test('los campos vacíos de FCM cuentan como ausentes', () {
      expect(
        destinoDeDatosPush(const {'tipo': 'registro', 'evento_id': ''}),
        isNull,
      );
      expect(destinoDeDatosPush(const {}), isNull);
    });
  });

  group('debeApilarDestinoNotificacion', () {
    test('no vuelve a apilar el mismo hilo de comentarios', () {
      final destino = RoutePaths.comentariosLead('campana-9', 'lead-9');

      expect(
        debeApilarDestinoNotificacion(
          ubicacionActual: destino,
          destino: destino,
        ),
        isFalse,
      );
    });

    test(
      'bloquea el segundo callback antes de que el router cambie de ruta',
      () {
        final destino = RoutePaths.comentariosLead('campana-9', 'lead-9');

        expect(
          debeApilarDestinoNotificacion(
            ubicacionActual: RoutePaths.home,
            destino: destino,
            destinoPendiente: destino,
          ),
          isFalse,
        );
      },
    );

    test('permite abrir un hilo distinto desde otra pantalla', () {
      expect(
        debeApilarDestinoNotificacion(
          ubicacionActual: RoutePaths.home,
          destino: RoutePaths.comentariosLead('campana-9', 'lead-9'),
        ),
        isTrue,
      );
    });
  });
}
