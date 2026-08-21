import '../../core/router/route_paths.dart';
import '../../data/models/notificacion.dart';

/// Ruta a la que lleva una notificación al tocarla.
///
/// El inbox y el push comparten este mapeo: la fila de la lista y el toque
/// sobre el aviso del sistema tienen que llevar al mismo sitio. Devuelve
/// `null` cuando la notificación no apunta a nada abrible (por ejemplo un
/// aviso de un evento que ya se eliminó), y quien llama decide el respaldo.
String? destinoDeNotificacion(NotificacionInbox notificacion) {
  return _destino(
    tipo: notificacion.tipo,
    eventoId: notificacion.eventoId,
    leadId: notificacion.leadId,
    eventoLeadId: notificacion.eventoLeadId,
  );
}

/// Igual que [destinoDeNotificacion], pero desde el `data` de un mensaje FCM,
/// donde todo llega como texto y los campos vacíos viajan como `''`.
String? destinoDeDatosPush(Map<String, dynamic> data) {
  return _destino(
    tipo: TipoNotificacion.fromString(data['tipo'] as String?),
    eventoId: _texto(data['evento_id']),
    leadId: _texto(data['lead_id']),
    eventoLeadId: _texto(data['evento_lead_id']),
  );
}

String? _destino({
  required TipoNotificacion tipo,
  String? eventoId,
  String? leadId,
  String? eventoLeadId,
}) {
  if (tipo.esComentario) {
    if (leadId == null || eventoLeadId == null) return null;
    return RoutePaths.comentariosLead(eventoLeadId, leadId);
  }
  if (eventoId == null) return null;
  return RoutePaths.usarEvento(eventoId);
}

String? _texto(Object? valor) {
  if (valor is! String) return null;
  final limpio = valor.trim();
  return limpio.isEmpty ? null : limpio;
}
