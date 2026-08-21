/// Qué se queda en el disco del teléfono y qué se suelta.
///
/// El snapshot ya bajaba solo lo activo, pero nunca borraba: la caché de
/// `SharedPreferences` y las portadas de `Documents/imagenes_offline` crecían
/// sin techo con eventos terminados hacía meses.
///
/// Las decisiones viven como funciones puras, igual que `offline_policy.dart` y
/// `external_route_policy.dart`, para poder probarlas sin montar la app.
library;

/// Días que una copia local sobrevive a la fecha de su evento.
///
/// No es cero a propósito. Un evento que termina a medianoche mientras alguien
/// sigue acreditando en plena feria no puede quedarse sin lista, y sin red no
/// hay forma de recuperarla. Dos días cubren la jornada siguiente completa.
const Duration margenRetencionOffline = Duration(days: 2);

/// `true` si la copia local de un evento con esta [fecha] debe conservarse.
///
/// Compara solo fechas, igual que `Evento.yaOcurrio`: la hora del día no puede
/// decidir si el dispositivo tiene datos o no.
bool debeConservarseEnCache(
  DateTime fecha, {
  DateTime? ahora,
  Duration margen = margenRetencionOffline,
}) {
  final hoy = ahora ?? DateTime.now();
  final limite = DateTime(
    hoy.year,
    hoy.month,
    hoy.day,
  ).subtract(margen);
  final dia = DateTime(fecha.year, fecha.month, fecha.day);
  return !dia.isBefore(limite);
}

/// Ids que siguen mereciendo disco. Lo que no esté aquí se purga.
Set<String> idsVigentes<T>(
  Iterable<T> items, {
  required String Function(T) id,
  required DateTime Function(T) fecha,
  DateTime? ahora,
  Duration margen = margenRetencionOffline,
}) {
  return {
    for (final item in items)
      if (debeConservarseEnCache(fecha(item), ahora: ahora, margen: margen))
        id(item),
  };
}
