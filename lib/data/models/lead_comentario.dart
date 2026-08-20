import '../../../core/constants/app_role.dart';
import 'supabase_row_parsers.dart';

/// Tope del cuerpo en `lead_comentarios` (mismo check de la base).
const kLeadComentarioMaxCaracteres = 1000;

/// Comentario publicado en el hilo de un lead.
class LeadComentario {
  const LeadComentario({
    required this.id,
    required this.leadId,
    required this.cuerpo,
    this.autorId,
    this.autorNombre,
    this.autorRol,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String leadId;
  final String cuerpo;
  final String? autorId;
  final String? autorNombre;
  final String? autorRol;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool esPropio(String? perfilId) =>
      perfilId != null && perfilId.isNotEmpty && autorId == perfilId;

  bool get fueEditado {
    final creado = createdAt;
    final actualizado = updatedAt;
    if (creado == null || actualizado == null) return false;
    return actualizado.difference(creado).inSeconds.abs() >= 1;
  }

  String? get rolEtiqueta {
    final raw = autorRol?.trim();
    if (raw == null || raw.isEmpty) return null;
    return AppRole.fromString(raw).label;
  }

  factory LeadComentario.fromMap(Map<String, dynamic> map) {
    return LeadComentario(
      id: SupabaseRowParsers.asString(map['id']),
      leadId: SupabaseRowParsers.asString(map['lead_id']),
      cuerpo: SupabaseRowParsers.asString(map['cuerpo']),
      autorId: SupabaseRowParsers.asStringOrNull(map['autor_id']),
      autorNombre: SupabaseRowParsers.asStringOrNull(map['autor_nombre']),
      autorRol: SupabaseRowParsers.asStringOrNull(map['autor_rol']),
      createdAt: SupabaseRowParsers.parseDateTimeOrNull(map['created_at']),
      updatedAt: SupabaseRowParsers.parseDateTimeOrNull(map['updated_at']),
    );
  }
}
