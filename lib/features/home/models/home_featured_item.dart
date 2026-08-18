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
    this.registrados = 0,
    this.acreditados = 0,
    this.leads = 0,
    this.imagenUrl,
  });

  final HomeFeaturedKind kind;
  final String id;
  final String nombre;
  final DateTime fecha;
  final String lugar;
  final int registrados;
  final int acreditados;
  final int leads;
  final String? imagenUrl;

  bool get tieneImagen => imagenUrl != null && imagenUrl!.isNotEmpty;

  bool get esFijado =>
      kind == HomeFeaturedKind.eventoFijado ||
      kind == HomeFeaturedKind.campanaFijada;

  String get etiqueta => switch (kind) {
    HomeFeaturedKind.proximoEvento => 'PRÓXIMO EVENTO',
    HomeFeaturedKind.eventoFijado => 'EVENTO FIJADO',
    HomeFeaturedKind.campanaFijada => 'EVENTO DE LEADS FIJADO',
  };

  /// Se distingue del evento de registro para que dos fijados homónimos no
  /// ofrezcan el mismo botón.
  String get ctaLabel => kind == HomeFeaturedKind.campanaFijada
      ? 'Ver evento de leads'
      : 'Ver evento';

  bool get puedeEscanearQr => kind != HomeFeaturedKind.campanaFijada;

  String? get qrRoutePath =>
      puedeEscanearQr ? RoutePaths.acreditarQr(id) : null;

  String get porcentajeAcreditados {
    if (registrados <= 0) return '0%';
    return '${((acreditados / registrados) * 100).round()}%';
  }

  String get routePath => switch (kind) {
    HomeFeaturedKind.proximoEvento ||
    HomeFeaturedKind.eventoFijado => RoutePaths.usarEvento(id),
    HomeFeaturedKind.campanaFijada => RoutePaths.usarEventoLead(id),
  };

  HomeFeaturedItem copyWith({int? registrados, int? acreditados, int? leads}) {
    return HomeFeaturedItem(
      kind: kind,
      id: id,
      nombre: nombre,
      fecha: fecha,
      lugar: lugar,
      registrados: registrados ?? this.registrados,
      acreditados: acreditados ?? this.acreditados,
      leads: leads ?? this.leads,
      imagenUrl: imagenUrl,
    );
  }

  factory HomeFeaturedItem.proximoEvento(Evento evento) {
    return HomeFeaturedItem(
      kind: HomeFeaturedKind.proximoEvento,
      id: evento.id,
      nombre: evento.nombre,
      fecha: evento.fecha,
      lugar: evento.lugar ?? evento.pais ?? '',
      imagenUrl: evento.imagenUrl,
    );
  }

  factory HomeFeaturedItem.eventoFijado(Evento evento) {
    return HomeFeaturedItem(
      kind: HomeFeaturedKind.eventoFijado,
      id: evento.id,
      nombre: evento.nombre,
      fecha: evento.fecha,
      lugar: evento.lugar ?? evento.pais ?? '',
      imagenUrl: evento.imagenUrl,
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

/// Slider del home: fijados primero. El próximo evento cierra la lista si no
/// está ya fijado (si lo está, se muestra como fijado y no se duplica).
List<HomeFeaturedItem> ensamblarHomeFeaturedItems({
  required List<HomeFeaturedItem> fijados,
  HomeFeaturedItem? proximo,
}) {
  if (proximo == null) return List<HomeFeaturedItem>.of(fijados);
  if (fijados.any((item) => item.id == proximo.id)) {
    return List<HomeFeaturedItem>.of(fijados);
  }
  return [...fijados, proximo];
}
