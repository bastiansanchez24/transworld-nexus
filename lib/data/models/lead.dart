import 'supabase_row_parsers.dart';

/// Lead capturado en un evento de leads (`public.leads`).
class Lead {
  const Lead({
    required this.id,
    required this.eventoId,
    required this.nombreCompleto,
    this.empresa,
    this.cargo,
    this.telefono,
    this.email,
    this.descripcion,
    this.fotosUrls = const [],
    this.perfilId,
    this.createdAt,
    this.vendedorNombre,
    this.pendienteDeSincronizar = false,
  });

  final String id;
  final String eventoId;
  final String nombreCompleto;
  final String? empresa;
  final String? cargo;
  final String? telefono;
  final String? email;
  final String? descripcion;
  final List<String> fotosUrls;
  final String? perfilId;
  final DateTime? createdAt;

  /// Nombre del capturador (join `perfiles.nombre_completo`).
  final String? vendedorNombre;

  /// True cuando el lead vive solo en la cola offline local.
  final bool pendienteDeSincronizar;

  factory Lead.fromMap(Map<String, dynamic> map) {
    return Lead(
      id: SupabaseRowParsers.asString(map['id']),
      eventoId: SupabaseRowParsers.asString(map['evento_id']),
      nombreCompleto: SupabaseRowParsers.asString(map['nombre_completo']),
      empresa: SupabaseRowParsers.asStringOrNull(map['empresa']),
      cargo: SupabaseRowParsers.asStringOrNull(map['cargo']),
      telefono: SupabaseRowParsers.asStringOrNull(map['telefono']),
      email: SupabaseRowParsers.asStringOrNull(map['email']),
      descripcion: SupabaseRowParsers.asStringOrNull(map['descripcion']),
      fotosUrls: SupabaseRowParsers.parseStringList(map['fotos_urls']),
      perfilId: SupabaseRowParsers.asStringOrNull(map['perfil_id']),
      createdAt: SupabaseRowParsers.parseDateTimeOrNull(map['created_at']),
      vendedorNombre: SupabaseRowParsers.nombrePerfilEmbed(map['perfiles']),
      pendienteDeSincronizar:
          (map['pendiente_de_sincronizar'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'evento_id': eventoId,
      'nombre_completo': nombreCompleto,
      'empresa': empresa,
      'cargo': cargo,
      'telefono': telefono,
      'email': email,
      'descripcion': descripcion,
      'fotos_urls': fotosUrls,
      if (perfilId != null) 'perfil_id': perfilId,
    };
  }

  Lead copyWith({
    String? id,
    String? nombreCompleto,
    String? empresa,
    String? cargo,
    String? telefono,
    String? email,
    String? descripcion,
    List<String>? fotosUrls,
    String? perfilId,
    bool? pendienteDeSincronizar,
    String? vendedorNombre,
  }) {
    return Lead(
      id: id ?? this.id,
      eventoId: eventoId,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      empresa: empresa ?? this.empresa,
      cargo: cargo ?? this.cargo,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      descripcion: descripcion ?? this.descripcion,
      fotosUrls: fotosUrls ?? this.fotosUrls,
      perfilId: perfilId ?? this.perfilId,
      createdAt: createdAt,
      vendedorNombre: vendedorNombre ?? this.vendedorNombre,
      pendienteDeSincronizar:
          pendienteDeSincronizar ?? this.pendienteDeSincronizar,
    );
  }
}
