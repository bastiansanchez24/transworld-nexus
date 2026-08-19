import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/data/models/evento.dart';
import 'package:transworld_nexus/data/models/evento_lead.dart';
import 'package:transworld_nexus/features/home/models/home_featured_item.dart';

HomeFeaturedItem _item({required HomeFeaturedKind kind, required String id}) {
  return HomeFeaturedItem(
    kind: kind,
    id: id,
    nombre: id,
    fecha: DateTime(2026, 8, 14),
  );
}

void main() {
  test('el evento fijado queda primero y el próximo al final', () {
    final fijado = _item(kind: HomeFeaturedKind.eventoFijado, id: 'fijado');
    final proximo = _item(kind: HomeFeaturedKind.proximoEvento, id: 'proximo');

    final items = ensamblarHomeFeaturedItems(
      fijados: [fijado],
      proximo: proximo,
    );

    expect(items.map((item) => item.id), ['fijado', 'proximo']);
    expect(items.first.kind, HomeFeaturedKind.eventoFijado);
  });

  test('si el próximo también está fijado no se duplica y manda el fijado', () {
    final fijado = _item(kind: HomeFeaturedKind.eventoFijado, id: 'mismo');
    final proximo = _item(kind: HomeFeaturedKind.proximoEvento, id: 'mismo');

    final items = ensamblarHomeFeaturedItems(
      fijados: [fijado],
      proximo: proximo,
    );

    expect(items, hasLength(1));
    expect(items.single.kind, HomeFeaturedKind.eventoFijado);
  });

  test('sin fijados solo queda el próximo evento', () {
    final proximo = _item(kind: HomeFeaturedKind.proximoEvento, id: 'proximo');

    final items = ensamblarHomeFeaturedItems(
      fijados: const [],
      proximo: proximo,
    );

    expect(items, hasLength(1));
    expect(items.single.kind, HomeFeaturedKind.proximoEvento);
  });

  test('copia la imagen de portada del evento', () {
    const url = 'https://cdn.example/evento.jpg';
    final evento = Evento(
      id: 'e1',
      nombre: 'Taller',
      fecha: DateTime(2026, 8, 14),
      imagenUrl: url,
    );

    expect(HomeFeaturedItem.proximoEvento(evento).imagenUrl, url);
    expect(HomeFeaturedItem.eventoFijado(evento).tieneImagen, isTrue);
    expect(
      HomeFeaturedItem.proximoEvento(evento).copyWith(registrados: 3).imagenUrl,
      url,
    );
  });

  test('la actividad fijada copia la imagen y ofrece capturar lead', () {
    final campana = EventoLead(
      id: 'c1',
      nombre: 'Feria',
      fecha: DateTime(2026, 9, 12),
      imagenUrl: 'https://cdn.example/feria.jpg',
    );
    final item = HomeFeaturedItem.campanaFijada(campana);

    expect(item.etiqueta, 'ACTIVIDAD FIJADA');
    expect(item.ctaLabel, 'Ver actividad');
    expect(item.ctaRoutePath, '/capturador/c1/usar');
    expect(item.secondaryCtaLabel, 'Capturar lead');
    expect(item.secondaryRoutePath, '/capturador/c1/capturar');
    expect(item.qrRoutePath, isNull);
    expect(item.tieneImagen, isTrue);
    expect(item.imagenUrl, 'https://cdn.example/feria.jpg');
  });
}
