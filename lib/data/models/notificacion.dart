enum TipoNotificacion {
  registro,
  acreditacion20,
  acreditacion50,
  acreditacion80,
  acreditacion100,
  leadComentario;

  static TipoNotificacion fromString(String? raw) {
    return switch (raw) {
      'acreditacion_20' => TipoNotificacion.acreditacion20,
      'acreditacion_50' => TipoNotificacion.acreditacion50,
      'acreditacion_80' => TipoNotificacion.acreditacion80,
      'acreditacion_100' => TipoNotificacion.acreditacion100,
      'lead_comentario' => TipoNotificacion.leadComentario,
      _ => TipoNotificacion.registro,
    };
  }

  bool get esAcreditacion => switch (this) {
    TipoNotificacion.registro => false,
    TipoNotificacion.leadComentario => false,
    _ => true,
  };

  bool get esComentario => this == TipoNotificacion.leadComentario;
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
    this.destinatarioId,
    this.leadId,
    this.eventoLeadId,
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

  /// Con valor, el aviso es solo para esa persona (comentarios de lead);
  /// `null` es el aviso global de siempre (registros, hitos de acreditación).
  final String? destinatarioId;
  final String? leadId;
  final String? eventoLeadId;
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
      destinatarioId: map['destinatario_id'] as String?,
      leadId: map['lead_id'] as String?,
      eventoLeadId: map['evento_lead_id'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      leida: leida,
    );
  }
}
