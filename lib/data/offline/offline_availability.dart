import '../../core/constants/supabase_tables.dart';
import '../../features/capturador/providers/capturador_providers.dart';
import 'offline_read_cache.dart';

/// Qué se puede abrir cuando no hay red.
///
/// La caché guarda solo el set activo (ver `offline_retention_policy.dart`), de
/// modo que un evento viejo sigue apareciendo en el catálogo pero ya no tiene
/// lista que mostrar. Las pantallas usan esto para apagar esas filas en vez de
/// dejar que lleven a un callejón sin salida.
///
/// Se consulta el índice de la tabla de listas, no el detalle: el detalle
/// también se resuelve desde el catálogo global, así que estaría disponible
/// para eventos cuya lista ya se purgó.
bool eventoDisponibleOffline(OfflineReadCache cache, String eventoId) {
  return cache.tieneEvento(SupabaseTables.registrados, eventoId);
}

bool actividadDisponibleOffline(
  OfflineReadCache cache,
  String actividadId, {
  required bool canViewAllLeads,
}) {
  return cache.tieneEvento(leadsCacheTabla(canViewAllLeads), actividadId);
}
