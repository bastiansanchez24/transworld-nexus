import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/data/models/evento_lead.dart';

void main() {
  test('el evento de leads sin origen es externo', () {
    final evento = EventoLead.fromMap({
      'id': 'el-1',
      'nombre': 'Feria retail',
      'fecha': '2026-09-12',
      'tipo_evento_lead': 'externo',
    });

    expect(evento.esInterno, isFalse);
    expect(evento.eventoOrigenId, isNull);
  });

  test('el interno conserva el id del evento del que nació', () {
    final evento = EventoLead.fromMap({
      'id': 'el-1',
      'nombre': 'Transworld Connect',
      'fecha': '2026-09-12',
      'tipo_evento_lead': 'interno',
      'evento_origen_id': 'evento-1',
    });

    expect(evento.esInterno, isTrue);
    expect(evento.eventoOrigenId, 'evento-1');
  });

  test('una fila anterior a la columna de tipo se lee como externa', () {
    final evento = EventoLead.fromMap({
      'id': 'el-legacy',
      'nombre': 'Campaña histórica',
      'fecha': '2025-03-01',
    });

    expect(evento.esInterno, isFalse);
  });

  test('internoDesdeEvento copia los metadatos y fija el vínculo', () {
    final evento = EventoLead.internoDesdeEvento(
      eventoOrigenId: 'evento-1',
      nombre: '  Transworld Connect  ',
      fecha: DateTime(2026, 9, 12),
      pais: 'Chile',
      tematica: 'Telecomunicaciones',
    );

    expect(evento.nombre, 'Transworld Connect');
    expect(evento.tipo, TipoEventoLead.interno);

    final insert = evento.toInsertMap();
    expect(insert['tipo_evento_lead'], 'interno');
    expect(insert['evento_origen_id'], 'evento-1');
    expect(insert['pais'], 'Chile');
  });

  test('el alta manual viaja como externa y sin evento de origen', () {
    final insert = EventoLead(
      id: '',
      nombre: 'Feria retail',
      fecha: DateTime(2026, 9, 12),
    ).toInsertMap();

    expect(insert['tipo_evento_lead'], 'externo');
    expect(insert['evento_origen_id'], isNull);
  });

  test('editar un interno no lo puede convertir en externo', () {
    final interno = EventoLead.internoDesdeEvento(
      eventoOrigenId: 'evento-1',
      nombre: 'Transworld Connect',
      fecha: DateTime(2026, 9, 12),
    );

    // El formulario reconstruye el modelo desde sus campos, así que sin este
    // recorte el update arrastraría el tipo por defecto (externo).
    final update = interno.copyWith(nombre: 'Otro nombre').toUpdateMap();

    expect(update.containsKey('tipo_evento_lead'), isFalse);
    expect(update.containsKey('evento_origen_id'), isFalse);
    expect(update['nombre'], 'Otro nombre');
  });

  test('copyWith conserva el vínculo con el evento de origen', () {
    final interno = EventoLead.internoDesdeEvento(
      eventoOrigenId: 'evento-1',
      nombre: 'Transworld Connect',
      fecha: DateTime(2026, 9, 12),
    );

    final editado = interno.copyWith(pais: 'Perú');

    expect(editado.esInterno, isTrue);
    expect(editado.eventoOrigenId, 'evento-1');
  });
}
