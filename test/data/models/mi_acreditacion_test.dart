import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/data/models/mi_acreditacion.dart';

MiAcreditacion _fila({
  required String eventoId,
  required String eventoNombre,
  required String nombre,
  String? empresa,
  String? cargo,
}) {
  return MiAcreditacion.fromMap({
    'evento_id': eventoId,
    'evento_nombre': eventoNombre,
    'evento_fecha': '2026-08-20',
    'registrado_id': 'r-$nombre',
    'nombre_completo': nombre,
    'empresa': empresa,
    'cargo': cargo,
    'acreditado_en': '2026-08-20T14:30:00Z',
  });
}

void main() {
  test('agrupa por evento conservando el orden del RPC', () {
    final grupos = AcreditacionesPorEvento.agrupar([
      _fila(eventoId: 'e2', eventoNombre: 'Expo Sur', nombre: 'Ada'),
      _fila(eventoId: 'e2', eventoNombre: 'Expo Sur', nombre: 'Grace'),
      _fila(eventoId: 'e1', eventoNombre: 'Expo Norte', nombre: 'Alan'),
    ]);

    expect(grupos.map((g) => g.eventoId), ['e2', 'e1']);
    expect(grupos.first.eventoNombre, 'Expo Sur');
    expect(grupos.first.acreditados.map((a) => a.nombreCompleto), [
      'Ada',
      'Grace',
    ]);
    expect(grupos.last.acreditados, hasLength(1));
  });

  test('un evento que reaparece más abajo no abre un grupo nuevo', () {
    final grupos = AcreditacionesPorEvento.agrupar([
      _fila(eventoId: 'e1', eventoNombre: 'Expo', nombre: 'Ada'),
      _fila(eventoId: 'e2', eventoNombre: 'Feria', nombre: 'Alan'),
      _fila(eventoId: 'e1', eventoNombre: 'Expo', nombre: 'Grace'),
    ]);

    expect(grupos, hasLength(2));
    expect(grupos.first.acreditados.map((a) => a.nombreCompleto), [
      'Ada',
      'Grace',
    ]);
  });

  test('sin acreditaciones no hay grupos', () {
    expect(AcreditacionesPorEvento.agrupar(const []), isEmpty);
  });

  test('el detalle no deja separadores colgando', () {
    expect(
      _fila(
        eventoId: 'e1',
        eventoNombre: 'Expo',
        nombre: 'Ada',
        empresa: 'Transworld',
        cargo: 'Gerente',
      ).detalle,
      'Transworld · Gerente',
    );
    expect(
      _fila(
        eventoId: 'e1',
        eventoNombre: 'Expo',
        nombre: 'Ada',
        empresa: 'Transworld',
      ).detalle,
      'Transworld',
    );
    expect(
      _fila(eventoId: 'e1', eventoNombre: 'Expo', nombre: 'Ada').detalle,
      isEmpty,
    );
  });
}
