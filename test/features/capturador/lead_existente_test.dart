import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/data/models/lead.dart';
import 'package:transworld_nexus/data/models/lead_existente.dart';

Lead _lead({
  required String id,
  String? email,
  DateTime? createdAt,
  String? perfilId,
}) {
  return Lead(
    id: id,
    eventoId: 'campana-1',
    nombreCompleto: 'Lead $id',
    email: email,
    perfilId: perfilId,
    createdAt: createdAt,
  );
}

void main() {
  test('normaliza email como el RPC: trim y minúsculas', () {
    expect(emailLeadNormalizado('  Ada@Expo.cl '), 'ada@expo.cl');
    expect(emailLeadNormalizado(''), isNull);
    expect(emailLeadNormalizado('   '), isNull);
    expect(emailLeadNormalizado(null), isNull);
  });

  test('encuentra el lead más antiguo con el mismo email', () {
    final tarde = _lead(
      id: 'b',
      email: 'ada@expo.cl',
      createdAt: DateTime(2026, 8, 20, 12),
    );
    final temprano = _lead(
      id: 'a',
      email: 'ADA@expo.cl',
      createdAt: DateTime(2026, 8, 20, 9),
    );
    final otro = _lead(id: 'c', email: 'otro@expo.cl');

    final hallado = leadPorEmailEnLista([
      tarde,
      temprano,
      otro,
    ], ' ada@EXPO.cl ');
    expect(hallado?.id, 'a');
  });

  test('no hay match si el email está vacío o no existe', () {
    final leads = [
      _lead(id: 'a', email: 'ada@expo.cl'),
      _lead(id: 'b', email: null),
    ];
    expect(leadPorEmailEnLista(leads, ''), isNull);
    expect(leadPorEmailEnLista(leads, 'nadie@expo.cl'), isNull);
  });

  test('marca esPropio cuando el capturador es el perfil actual', () {
    final propio = _lead(id: 'a', email: 'ada@expo.cl', perfilId: 'user-1');
    final ajeno = _lead(id: 'b', email: 'eva@expo.cl', perfilId: 'user-2');

    expect(
      leadExistenteEnLista(
        [propio],
        'ada@expo.cl',
        perfilId: 'user-1',
      )?.esPropio,
      isTrue,
    );
    expect(
      leadExistenteEnLista(
        [ajeno],
        'eva@expo.cl',
        perfilId: 'user-1',
      )?.esPropio,
      isFalse,
    );
  });
}
