import 'supabase_row_parsers.dart';

/// Evento del módulo Capturador de leads (`public.eventos_leads`).
/// Independiente de [Evento] / `public.eventos` (registro/acreditación).
class EventoLead {
  const EventoLead({
    required this.id,
    required this.nombre,
    required this.fecha,
    this.pais,
    this.tematica,
    this.certificacionCapacitacion = false,
    this.perfilId,
    this.createdAt,
  });

  final String id;
  final String nombre;
  final DateTime fecha;
  final String? pais;
  final String? tematica;
  final bool certificacionCapacitacion;
  final String? perfilId;
  final DateTime? createdAt;

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
      if (perfilId != null) 'perfil_id': perfilId,
    };
  }

  EventoLead copyWith({
    String? nombre,
    DateTime? fecha,
    String? pais,
    String? tematica,
    bool? certificacionCapacitacion,
    String? perfilId,
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
      createdAt: createdAt,
    );
  }
}
