import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/data/offline/offline_retention_policy.dart';

void main() {
  // Fecha fija: la política compara días, así que un test anclado a
  // `DateTime.now()` fallaría al correr justo en un cambio de día.
  final hoy = DateTime(2026, 8, 21, 15, 30);

  group('debeConservarseEnCache', () {
    test('un evento futuro se conserva', () {
      expect(
        debeConservarseEnCache(DateTime(2026, 9, 1), ahora: hoy),
        isTrue,
      );
    });

    test('el evento de hoy se conserva aunque ya sea de tarde', () {
      expect(
        debeConservarseEnCache(DateTime(2026, 8, 21), ahora: hoy),
        isTrue,
      );
    });

    test('el que terminó ayer sigue en disco: alguien puede seguir operando', () {
      expect(
        debeConservarseEnCache(DateTime(2026, 8, 20), ahora: hoy),
        isTrue,
      );
    });

    test('el último día del margen todavía se conserva', () {
      // margen = 2 días → el límite es el 19.
      expect(
        debeConservarseEnCache(DateTime(2026, 8, 19), ahora: hoy),
        isTrue,
      );
    });

    test('pasado el margen se libera', () {
      expect(
        debeConservarseEnCache(DateTime(2026, 8, 18), ahora: hoy),
        isFalse,
      );
      expect(
        debeConservarseEnCache(DateTime(2026, 5, 1), ahora: hoy),
        isFalse,
      );
    });

    test('la hora del evento no cambia la decisión', () {
      expect(
        debeConservarseEnCache(
          DateTime(2026, 8, 18, 23, 59),
          ahora: hoy,
        ),
        isFalse,
      );
    });

    test('con margen cero se libera el día siguiente', () {
      expect(
        debeConservarseEnCache(
          DateTime(2026, 8, 20),
          ahora: hoy,
          margen: Duration.zero,
        ),
        isFalse,
      );
      expect(
        debeConservarseEnCache(
          DateTime(2026, 8, 21),
          ahora: hoy,
          margen: Duration.zero,
        ),
        isTrue,
      );
    });
  });

  group('idsVigentes', () {
    final items = [
      (id: 'futuro', fecha: DateTime(2026, 9, 1)),
      (id: 'hoy', fecha: DateTime(2026, 8, 21)),
      (id: 'en-margen', fecha: DateTime(2026, 8, 20)),
      (id: 'vencido', fecha: DateTime(2026, 7, 1)),
    ];

    test('conserva lo vigente y descarta lo vencido', () {
      final vigentes = idsVigentes(
        items,
        id: (item) => item.id,
        fecha: (item) => item.fecha,
        ahora: hoy,
      );

      expect(vigentes, {'futuro', 'hoy', 'en-margen'});
    });

    test('una lista vacía no conserva nada', () {
      expect(
        idsVigentes(
          const <({String id, DateTime fecha})>[],
          id: (item) => item.id,
          fecha: (item) => item.fecha,
          ahora: hoy,
        ),
        isEmpty,
      );
    });
  });
}
