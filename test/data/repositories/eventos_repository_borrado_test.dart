import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:transworld_nexus/data/repositories/eventos_repository.dart';

void main() {
  test('el evento con evento de leads interno no se puede borrar', () {
    // Lo que devuelve PostgREST cuando el FK RESTRICT de
    // eventos_leads.evento_origen_id rechaza el DELETE.
    final error = EventosRepository.errorDeBorrado(
      const PostgrestException(
        message:
            'update or delete on table "eventos" violates foreign key '
            'constraint "eventos_leads_evento_origen_id_fkey"',
        code: '23503',
      ),
    );

    expect(error, isA<EventoConEventoLeadException>());
    expect(error.toString(), contains('actividad de captura'));
  });

  test('otros fallos de borrado se propagan tal cual', () {
    const original = PostgrestException(
      message: 'permission denied for table eventos',
      code: '42501',
    );

    expect(EventosRepository.errorDeBorrado(original), same(original));
  });
}
