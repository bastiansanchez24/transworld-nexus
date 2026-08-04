import '../../../core/router/route_paths.dart';
import '../../../data/models/evento.dart';
import '../../../data/models/evento_lead.dart';

enum HomeFeaturedKind { proximoEvento, eventoFijado, campanaFijada }

/// Ítem mostrable en la card/slider del header del home.
class HomeFeaturedItem {
  const HomeFeaturedItem({
    required this.kind,
    required this.id,
    required this.nombre,
    required this.fecha,
    this.lugar = '',
  });

  final HomeFeaturedKind kind;
  final String id;
  final String nombre;
  final DateTime fecha;
  final String lugar;

  bool get esFijado =>
      kind == HomeFeaturedKind.eventoFijado ||
      kind == HomeFeaturedKind.campanaFijada;

  String get etiqueta => switch (kind) {
        HomeFeaturedKind.proximoEvento => 'PRÓXIMO EVENTO',
        HomeFeaturedKind.eventoFijado => 'EVENTO FIJADO',
        HomeFeaturedKind.campanaFijada => 'CAMPAÑA FIJADA',
      };

  String get routePath => switch (kind) {
        HomeFeaturedKind.proximoEvento ||
        HomeFeaturedKind.eventoFijado =>
          RoutePaths.usarEvento(id),
        HomeFeaturedKind.campanaFijada => RoutePaths.usarEventoLead(id),
      };

  factory HomeFeaturedItem.proximoEvento(Evento evento) {
    return HomeFeaturedItem(
      kind: HomeFeaturedKind.proximoEvento,
      id: evento.id,
      nombre: evento.nombre,
      fecha: evento.fecha,
      lugar: evento.lugar ?? evento.pais ?? '',
    );
  }

  factory HomeFeaturedItem.eventoFijado(Evento evento) {
    return HomeFeaturedItem(
      kind: HomeFeaturedKind.eventoFijado,
      id: evento.id,
      nombre: evento.nombre,
      fecha: evento.fecha,
      lugar: evento.lugar ?? evento.pais ?? '',
    );
  }

  factory HomeFeaturedItem.campanaFijada(EventoLead campana) {
    return HomeFeaturedItem(
      kind: HomeFeaturedKind.campanaFijada,
      id: campana.id,
      nombre: campana.nombre,
      fecha: campana.fecha,
      lugar: campana.pais ?? '',
    );
  }
}
