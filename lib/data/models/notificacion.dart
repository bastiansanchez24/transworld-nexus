enum TipoNotificacion {
  registro,
  acreditacion20,
  acreditacion50,
  acreditacion80,
  acreditacion100;

  static TipoNotificacion fromString(String? raw) {
    return switch (raw) {
      'acreditacion_20' => TipoNotificacion.acreditacion20,
      'acreditacion_50' => TipoNotificacion.acreditacion50,
      'acreditacion_80' => TipoNotificacion.acreditacion80,
      'acreditacion_100' => TipoNotificacion.acreditacion100,
      _ => TipoNotificacion.registro,
    };
  }

  bool get esAcreditacion => switch (this) {
        TipoNotificacion.registro => false,
        _ => true,
      };
}

class NotificacionInbox {
  const NotificacionInbox({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.cuerpo,
    required this.nombreRegistrado,
    required this.nombreEvento,
    this.registradoId,
    this.eventoId,
    this.createdAt,
    this.leida = false,
  });

  final String id;
  final TipoNotificacion tipo;
  final String titulo;
  final String cuerpo;
  final String nombreRegistrado;
  final String nombreEvento;
  final String? registradoId;
  final String? eventoId;
  final DateTime? createdAt;
  final bool leida;

  factory NotificacionInbox.fromMap(
    Map<String, dynamic> map, {
    required bool leida,
  }) {
    return NotificacionInbox(
      id: map['id'] as String,
      tipo: TipoNotificacion.fromString(map['tipo'] as String?),
      titulo: map['titulo'] as String,
      cuerpo: map['cuerpo'] as String,
      nombreRegistrado: map['nombre_registrado'] as String,
      nombreEvento: map['nombre_evento'] as String,
      registradoId: map['registrado_id'] as String?,
      eventoId: map['evento_id'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      leida: leida,
    );
  }
}
