import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migracion =
      'supabase/migrations/'
      '202608211600_actividades_captura_por_evento_autorizado.sql';

  test('la migración exige evento de origen autorizado en todas las capas', () {
    final sql = File(migracion).readAsStringSync();

    expect(sql, contains('public.cl_campana_autorizada(evento_id)'));
    expect(sql, contains('evento_origen_id IS NOT NULL'));
    expect(sql, contains('public.rpe_puede_operar_evento(evento_origen_id)'));
    expect(sql, contains('public.cl_campana_autorizada(p_evento_id)'));
    expect(sql, contains('public.cl_campana_autorizada(evento_lead_id)'));
  });

  test('los RPC originales quedan privados detrás de wrappers autorizados', () {
    final sql = File(migracion).readAsStringSync();

    expect(
      sql,
      contains(
        'cl_guardar_lead_sin_scope(\n'
        '  uuid, text, text, text, text, text, text, uuid\n'
        ') FROM PUBLIC, anon, authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'cl_resumen_campana_sin_scope(uuid)\n'
        '  FROM PUBLIC, anon, authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'cl_buscar_lead_por_email_sin_scope(uuid, text)\n'
        '  FROM PUBLIC, anon, authenticated',
      ),
    );
  });

  test('notificaciones de comentarios respetan revocaciones del evento', () {
    final sql = File(migracion).readAsStringSync();

    expect(sql, contains('AND public.rpe_puede_operar_evento(p_evento_id)'));
    expect(sql, contains('ue.evento_id = v_evento_origen_id'));
    expect(sql, contains('lead_id, evento_lead_id, evento_id'));
  });

  test('las fotos privadas de leads heredan el permiso de la campaña', () {
    final sql = File(migracion).readAsStringSync();

    expect(sql, contains('public.rpe_puede_escribir_imagen'));
    expect(sql, contains('public.cl_campana_autorizada(l.evento_id)'));
  });
}
