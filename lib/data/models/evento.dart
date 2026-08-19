enum TipoRegistroEvento {
  comercial,
  cliente;

  static TipoRegistroEvento fromString(String? raw) {
    return TipoRegistroEvento.values.firstWhere(
      (t) => t.name == raw,
      orElse: () => TipoRegistroEvento.comercial,
    );
  }
}

class Evento {
  const Evento({
    required this.id,
    required this.nombre,
    required this.fecha,
    this.pais,
    this.tematica,
    this.creadoPor,
    this.direccion,
    this.lugar,
    this.certificacionCapacitacion = false,
    this.activo = true,
    this.imagenUrl,
    this.tipoRegistro = TipoRegistroEvento.comercial,
  });

  final String id;
  final String nombre;
  final DateTime fecha;
  final String? pais;
  final String? tematica;
  final String? creadoPor;
  final String? direccion;
  final String? lugar;
  final bool certificacionCapacitacion;
  final bool activo;
  final String? imagenUrl;
  final TipoRegistroEvento tipoRegistro;

  bool get yaOcurrio {
    final hoy = DateTime.now();
    final soloFecha = DateTime(hoy.year, hoy.month, hoy.day);
    return fecha.isBefore(soloFecha);
  }

  factory Evento.fromMap(Map<String, dynamic> map) {
    return Evento(
      id: map['id'] as String,
      nombre: map['nombre'] as String,
      fecha: DateTime.parse(map['fecha'] as String),
      pais: map['pais'] as String?,
      tematica: map['tematica'] as String?,
      creadoPor: map['creado_por'] as String?,
      direccion: map['direccion'] as String?,
      lugar: map['lugar'] as String?,
      certificacionCapacitacion:
          (map['certificacion_capacitacion'] as bool?) ?? false,
      activo: (map['activo'] as bool?) ?? true,
      imagenUrl: map['imagen_url'] as String?,
      tipoRegistro: TipoRegistroEvento.fromString(
        map['tipo_registro'] as String?,
      ),
    );
  }

  /// Copia serializable para la caché offline. Usa las claves de
  /// [Evento.fromMap] para rehidratar por el mismo camino que la fila de
  /// `eventos` (a diferencia de [toInsertMap], que omite el id).
  Map<String, dynamic> toCacheMap() {
    return {
      'id': id,
      'nombre': nombre,
      'fecha': fecha.toIso8601String(),
      'pais': pais,
      'tematica': tematica,
      'creado_por': creadoPor,
      'direccion': direccion,
      'lugar': lugar,
      'certificacion_capacitacion': certificacionCapacitacion,
      'activo': activo,
      'imagen_url': imagenUrl,
      'tipo_registro': tipoRegistro.name,
    };
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'nombre': nombre,
      'fecha': fecha.toIso8601String().split('T').first,
      'pais': pais,
      'tematica': tematica,
      'direccion': direccion,
      'lugar': lugar,
      'certificacion_capacitacion': certificacionCapacitacion,
      'activo': activo,
      'imagen_url': imagenUrl,
      'tipo_registro': tipoRegistro.name,
    };
  }

  Evento copyWith({
    String? nombre,
    DateTime? fecha,
    String? pais,
    String? tematica,
    String? direccion,
    String? lugar,
    bool? certificacionCapacitacion,
    bool? activo,
    String? imagenUrl,
    TipoRegistroEvento? tipoRegistro,
  }) {
    return Evento(
      id: id,
      nombre: nombre ?? this.nombre,
      fecha: fecha ?? this.fecha,
      pais: pais ?? this.pais,
      tematica: tematica ?? this.tematica,
      creadoPor: creadoPor,
      direccion: direccion ?? this.direccion,
      lugar: lugar ?? this.lugar,
      certificacionCapacitacion:
          certificacionCapacitacion ?? this.certificacionCapacitacion,
      activo: activo ?? this.activo,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      tipoRegistro: tipoRegistro ?? this.tipoRegistro,
    );
  }
}
