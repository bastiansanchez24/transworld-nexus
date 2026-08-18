/// Utilidades compartidas para mapear filas de PostgREST/Supabase a modelos
/// Dart. Centraliza el manejo de UUIDs, fechas y embeds anidados.
class SupabaseRowParsers {
  SupabaseRowParsers._();

  static String asString(dynamic value) => value.toString();

  static String? asStringOrNull(dynamic value) =>
      value?.toString();

  static DateTime parseDate(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.parse(value.toString());
  }

  static DateTime? parseDateTimeOrNull(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  /// Lee `nombre_completo` desde un embed `perfiles` (objeto o lista).
  static String? nombrePerfilEmbed(dynamic embed) {
    if (embed is Map) {
      return asStringOrNull(embed['nombre_completo']);
    }
    if (embed is List && embed.isNotEmpty && embed.first is Map) {
      return asStringOrNull((embed.first as Map)['nombre_completo']);
    }
    return null;
  }

  static List<String> parseStringList(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item != null) item.toString(),
    ].where((s) => s.isNotEmpty).toList();
  }
}
