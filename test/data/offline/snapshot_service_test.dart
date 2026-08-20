import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/data/models/evento.dart';
import 'package:transworld_nexus/data/models/evento_lead.dart';
import 'package:transworld_nexus/data/offline/snapshot_service.dart';

void main() {
  final hoy = DateTime.now();
  final ayer = hoy.subtract(const Duration(days: 1));
  final manana = hoy.add(const Duration(days: 1));

  Evento evento(
    String id, {
    required DateTime fecha,
    bool activo = true,
    String? nombre,
  }) {
    return Evento(id: id, nombre: nombre ?? id, fecha: fecha, activo: activo);
  }

  EventoLead actividad(String id, {required DateTime fecha, String? origenId}) {
    return EventoLead(
      id: id,
      nombre: id,
      fecha: fecha,
      eventoOrigenId: origenId,
    );
  }

  group('SnapshotService.eventosDelSnapshot', () {
    test('baja los activos que aún no han ocurrido', () {
      final elegidos = SnapshotService.eventosDelSnapshot([
        evento('hoy', fecha: hoy),
        evento('futuro', fecha: manana),
      ]);

      expect(elegidos.map((e) => e.id), ['hoy', 'futuro']);
    });

    test('un evento pausado por el admin no ocupa disco', () {
      final elegidos = SnapshotService.eventosDelSnapshot([
        evento('pausado', fecha: manana, activo: false),
      ]);

      expect(elegidos, isEmpty);
    });

    test('lo ya finalizado deja de bajarse', () {
      final elegidos = SnapshotService.eventosDelSnapshot([
        evento('pasado', fecha: ayer),
        evento('vigente', fecha: hoy),
      ]);

      expect(elegidos.map((e) => e.id), ['vigente']);
    });
  });

  group('SnapshotService.actividadesDelSnapshot', () {
    test('se refrescan las que siguen vigentes', () {
      final elegidas = SnapshotService.actividadesDelSnapshot([
        actividad('vieja', fecha: ayer),
        actividad('viva', fecha: hoy),
      ]);

      expect(elegidas.map((e) => e.id), ['viva']);
    });
  });

  group('SnapshotService.campanasDelSnapshot', () {
    test('el interno baja todas las actividades vigentes', () {
      final elegidas = SnapshotService.campanasDelSnapshot(
        actividades: [
          actividad('ajena', fecha: manana),
          actividad('propia', fecha: manana, origenId: 'evento-1'),
        ],
        eventosVisibles: [evento('evento-1', fecha: manana)],
        esExterno: false,
      );

      expect(elegidas.map((e) => e.id), ['ajena', 'propia']);
    });

    test('el externo solo baja las ligadas a sus eventos', () {
      final elegidas = SnapshotService.campanasDelSnapshot(
        actividades: [
          actividad('ajena', fecha: manana),
          actividad('por-id', fecha: manana, origenId: 'evento-1'),
          actividad('Expo', fecha: manana),
          actividad('pasada', fecha: ayer, origenId: 'evento-1'),
        ],
        eventosVisibles: [evento('evento-1', fecha: manana, nombre: 'Expo')],
        esExterno: true,
      );

      expect(elegidas.map((e) => e.id), ['por-id', 'Expo']);
    });
  });

  group('SnapshotService.esErrorSinAccesoResumen', () {
    test('reconoce el 42501 del RPC de conteos', () {
      const crudo =
          'PostgrestException(message: Sin acceso al resumen de la campaña, '
          'code: 42501, details: Forbidden, hint: null)';

      expect(SnapshotService.esErrorSinAccesoResumen(crudo), isTrue);
      expect(SnapshotService.esErrorSinAccesoResumen('timeout'), isFalse);
    });
  });
}
