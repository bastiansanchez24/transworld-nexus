import 'supabase_row_parsers.dart';

/// Origen de un [EventoLead]: nacido de un evento de registro o creado a mano.
enum TipoEventoLead {
  interno,
  externo;

  static TipoEventoLead fromString(String? raw) {
    return TipoEventoLead.values.firstWhere(
      (t) => t.name == raw,
      orElse: () => TipoEventoLead.externo,
    );
  }
}

/// Actividad de captura de leads (`public.eventos_leads`).
/// Independiente de [Evento] / `public.eventos` (registro/acreditación).
///
/// Las internas guardan en [eventoOrigenId] el evento de registro del que
/// nacieron (1:1); nombre, fecha, país, temática, certificación e imagen se
/// heredan de ese evento. Las externas no referencian ningún evento.
class EventoLead {
  const EventoLead({
    required this.id,
    required this.nombre,
    required this.fecha,
    this.pais,
    this.tematica,
    this.certificacionCapacitacion = false,
    this.perfilId,
    this.eventoOrigenId,
    this.tipo = TipoEventoLead.externo,
    this.imagenUrl,
    this.createdAt,
  });

  /// Interno a partir del evento de registro del que nace: copia sus metadatos
  /// y deja la referencia que evita crear una segunda actividad de captura.
  factory EventoLead.internoDesdeEvento({
    required String eventoOrigenId,
    required String nombre,
    required DateTime fecha,
    String? pais,
    String? tematica,
    bool certificacionCapacitacion = false,
    String? imagenUrl,
  }) {
    return EventoLead(
      id: '',
      nombre: nombre.trim(),
      fecha: fecha,
      pais: pais,
      tematica: tematica,
      certificacionCapacitacion: certificacionCapacitacion,
      eventoOrigenId: eventoOrigenId,
      tipo: TipoEventoLead.interno,
      imagenUrl: imagenUrl,
    );
  }

  final String id;
  final String nombre;
  final DateTime fecha;
  final String? pais;
  final String? tematica;
  final bool certificacionCapacitacion;
  final String? perfilId;
  final String? eventoOrigenId;
  final TipoEventoLead tipo;
  final String? imagenUrl;
  final DateTime? createdAt;

  bool get esInterno => tipo == TipoEventoLead.interno;

  bool get tieneImagen => imagenUrl != null && imagenUrl!.isNotEmpty;

  bool get yaOcurrio {
    final hoy = DateTime.now();
    final soloFecha = DateTime(hoy.year, hoy.month, hoy.day);
    return fecha.isBefore(soloFecha);
  }

  factory EventoLead.fromMap(Map<String, dynamic> map) {
    return EventoLead(
      id: SupabaseRowParsers.asString(map['id']),
      nombre: SupabaseRowParsers.asString(map['nombre']),
      fecha: SupabaseRowParsers.parseDate(map['fecha']),
      pais: SupabaseRowParsers.asStringOrNull(map['pais']),
      tematica: SupabaseRowParsers.asStringOrNull(map['tematica']),
      certificacionCapacitacion:
          (map['certificacion_capacitacion'] as bool?) ?? false,
      perfilId: SupabaseRowParsers.asStringOrNull(map['perfil_id']),
      eventoOrigenId: SupabaseRowParsers.asStringOrNull(
        map['evento_origen_id'],
      ),
      tipo: TipoEventoLead.fromString(
        map['tipo_evento_lead'] as String?,
      ),
      imagenUrl: SupabaseRowParsers.asStringOrNull(map['imagen_url']),
      createdAt: SupabaseRowParsers.parseDateTimeOrNull(map['created_at']),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'nombre': nombre,
      'fecha': fecha.toIso8601String().split('T').first,
      'pais': pais,
      'tematica': tematica,
      'certificacion_capacitacion': certificacionCapacitacion,
      'imagen_url': imagenUrl,
      'tipo_evento_lead': tipo.name,
      'evento_origen_id': eventoOrigenId,
      if (perfilId != null) 'perfil_id': perfilId,
    };
  }

  /// Campos que edita el formulario de una actividad **externa**.
  ///
  /// Las internas heredan del evento ligado: el cliente no persiste estos
  /// valores (el trigger de sync es la fuente de verdad).
  Map<String, dynamic> toUpdateMap() {
    if (esInterno) return const {};
    return {
      'nombre': nombre,
      'fecha': fecha.toIso8601String().split('T').first,
      'pais': pais,
      'tematica': tematica,
      'certificacion_capacitacion': certificacionCapacitacion,
    };
  }

  EventoLead copyWith({
    String? nombre,
    DateTime? fecha,
    String? pais,
    String? tematica,
    bool? certificacionCapacitacion,
    String? perfilId,
    String? imagenUrl,
  }) {
    return EventoLead(
      id: id,
      nombre: nombre ?? this.nombre,
      fecha: fecha ?? this.fecha,
      pais: pais ?? this.pais,
      tematica: tematica ?? this.tematica,
      certificacionCapacitacion:
          certificacionCapacitacion ?? this.certificacionCapacitacion,
      perfilId: perfilId ?? this.perfilId,
      eventoOrigenId: eventoOrigenId,
      tipo: tipo,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      createdAt: createdAt,
    );
  }
}
