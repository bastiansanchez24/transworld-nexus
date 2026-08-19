import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transworld_nexus/core/constants/fijados_limits.dart';
import 'package:transworld_nexus/core/permissions/permissions_onboarding.dart';
import 'package:transworld_nexus/core/utils/evento_list_sort.dart';

class _ItemOrdenable {
  const _ItemOrdenable({
    required this.id,
    required this.fecha,
    required this.finalizado,
  });

  final String id;
  final DateTime fecha;
  final bool finalizado;
}

void main() {
  group('compareEventoListItems', () {
    test('prioriza fijados sobre no fijados', () {
      final a = _ItemOrdenable(
        id: 'a',
        fecha: DateTime(2026, 8, 10),
        finalizado: false,
      );
      final b = _ItemOrdenable(
        id: 'b',
        fecha: DateTime(2026, 8, 1),
        finalizado: false,
      );

      expect(
        compareEventoListItems(
          a: a,
          b: b,
          fijados: {'a'},
          id: (e) => e.id,
          fecha: (e) => e.fecha,
          finalizado: (e) => e.finalizado,
        ),
        lessThan(0),
      );
    });

    test('ordena próximos por fecha ascendente', () {
      final cercano = _ItemOrdenable(
        id: 'cercano',
        fecha: DateTime(2026, 8, 5),
        finalizado: false,
      );
      final lejano = _ItemOrdenable(
        id: 'lejano',
        fecha: DateTime(2026, 12, 1),
        finalizado: false,
      );

      expect(
        compareEventoListItems(
          a: cercano,
          b: lejano,
          fijados: const {},
          id: (e) => e.id,
          fecha: (e) => e.fecha,
          finalizado: (e) => e.finalizado,
        ),
        lessThan(0),
      );
    });

    test('ordena finalizados por fecha descendente', () {
      final reciente = _ItemOrdenable(
        id: 'reciente',
        fecha: DateTime(2026, 7, 1),
        finalizado: true,
      );
      final antiguo = _ItemOrdenable(
        id: 'antiguo',
        fecha: DateTime(2025, 1, 1),
        finalizado: true,
      );

      expect(
        compareEventoListItems(
          a: reciente,
          b: antiguo,
          fijados: const {},
          id: (e) => e.id,
          fecha: (e) => e.fecha,
          finalizado: (e) => e.finalizado,
        ),
        lessThan(0),
      );
    });

    test('coloca próximos antes que finalizados', () {
      final proximo = _ItemOrdenable(
        id: 'proximo',
        fecha: DateTime(2026, 12, 31),
        finalizado: false,
      );
      final finalizado = _ItemOrdenable(
        id: 'finalizado',
        fecha: DateTime(2026, 1, 1),
        finalizado: true,
      );

      expect(
        compareEventoListItems(
          a: proximo,
          b: finalizado,
          fijados: const {},
          id: (e) => e.id,
          fecha: (e) => e.fecha,
          finalizado: (e) => e.finalizado,
        ),
        lessThan(0),
      );
    });
  });

  group('ordenarEventoListItems', () {
    test('ordena lista completa con fijados y estados mixtos', () {
      final items = [
        _ItemOrdenable(
          id: 'finalizado',
          fecha: DateTime(2025, 6, 1),
          finalizado: true,
        ),
        _ItemOrdenable(
          id: 'proximo-lejano',
          fecha: DateTime(2026, 12, 1),
          finalizado: false,
        ),
        _ItemOrdenable(
          id: 'fijado-finalizado',
          fecha: DateTime(2025, 1, 1),
          finalizado: true,
        ),
        _ItemOrdenable(
          id: 'proximo-cercano',
          fecha: DateTime(2026, 8, 1),
          finalizado: false,
        ),
      ];

      ordenarEventoListItems(
        items: items,
        fijados: {'fijado-finalizado'},
        id: (e) => e.id,
        fecha: (e) => e.fecha,
        finalizado: (e) => e.finalizado,
      );

      expect(items.map((e) => e.id).toList(), [
        'fijado-finalizado',
        'proximo-cercano',
        'proximo-lejano',
        'finalizado',
      ]);
    });
  });

  group('PermissionsOnboarding', () {
    test('marca permisos solicitados por usuario', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final onboarding = PermissionsOnboarding(prefs);

      expect(onboarding.yaSolicitados('user-1'), isFalse);
      await onboarding.marcarSolicitados('user-1');
      expect(onboarding.yaSolicitados('user-1'), isTrue);
      expect(onboarding.yaSolicitados('user-2'), isFalse);
    });
  });

  group('FijadosLimitException', () {
    test('expone el tope de 3 por tipo', () {
      expect(kMaxFijadosPorTipo, 3);
      expect(
        const FijadosLimitException('eventos').toString(),
        'Solo puedes fijar hasta 3 eventos a la vez.',
      );
    });
  });
}
