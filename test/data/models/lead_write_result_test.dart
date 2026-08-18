import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/data/models/lead_write_result.dart';

void main() {
  test('parsea duplicado propio y usa el mensaje acordado', () {
    final result = LeadWriteResult.fromRpc([
      {
        'resultado': 'duplicado',
        'lead_id': 'lead-1',
        'primer_capturador_nombre': 'Pedro Soto',
        'es_propio': true,
      },
    ]);

    expect(result.esDuplicado, isTrue);
    expect(result.mensajeDuplicado, 'Ya registraste este lead en este evento');
  });

  test('duplicado ajeno identifica al primer capturador', () {
    final result = LeadWriteResult.fromRpc({
      'resultado': 'duplicado',
      'lead_id': 'lead-1',
      'primer_capturador_nombre': 'Ana Pérez',
      'es_propio': false,
    });

    expect(
      result.mensajeDuplicado,
      'Este lead ya fue registrado por Ana Pérez',
    );
  });

  test('duplicado ajeno tiene fallback sin filtrar datos inexistentes', () {
    final result = LeadWriteResult.fromRpc({
      'resultado': 'duplicado',
      'lead_id': 'lead-1',
      'es_propio': false,
    });

    expect(
      result.mensajeDuplicado,
      'Este lead ya fue registrado por otro usuario',
    );
  });
}
