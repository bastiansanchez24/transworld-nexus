import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/data/models/lead_comentario.dart';

void main() {
  test('fueEditado solo si updated_at dista al menos un segundo', () {
    final creado = DateTime(2026, 8, 20, 12, 0);
    expect(
      LeadComentario(
        id: 'c1',
        leadId: 'l1',
        cuerpo: 'Hola',
        createdAt: creado,
        updatedAt: creado,
      ).fueEditado,
      isFalse,
    );
    expect(
      LeadComentario(
        id: 'c1',
        leadId: 'l1',
        cuerpo: 'Hola',
        createdAt: creado,
        updatedAt: creado.add(const Duration(seconds: 1)),
      ).fueEditado,
      isTrue,
    );
  });

  test('fromMap conserva autoría y marca de edición', () {
    final comentario = LeadComentario.fromMap({
      'id': 'c1',
      'lead_id': 'l1',
      'cuerpo': 'Hola',
      'autor_id': 'user-1',
      'autor_nombre': 'Bastian Abarca',
      'autor_rol': 'user',
      'created_at': '2026-08-20T12:00:00Z',
      'updated_at': '2026-08-20T14:00:00Z',
    });

    expect(comentario.autorId, 'user-1');
    expect(comentario.autorNombre, 'Bastian Abarca');
    expect(comentario.rolEtiqueta, 'Usuario');
    expect(comentario.fueEditado, isTrue);
  });

  test('la migración permite UPDATE de cuerpo y congela autoría', () {
    final sql = File(
      'supabase/migrations/202608201600_lead_comentarios_editar.sql',
    ).readAsStringSync();

    expect(sql, contains('GRANT SELECT, INSERT, UPDATE, DELETE'));
    expect(sql, contains('USING (autor_id = auth.uid())'));
    expect(sql, contains('NEW.autor_id := OLD.autor_id'));
    expect(sql, contains('NEW.autor_nombre := OLD.autor_nombre'));
    expect(sql, contains('NEW.autor_rol := OLD.autor_rol'));
    expect(sql, contains('OR public.rpe_is_admin()'));
    expect(sql, contains('OR public.rpe_is_organizador()'));
  });
}
