import '../../core/constants/app_role.dart';

class Perfil {
  const Perfil({
    required this.id,
    required this.nombreCompleto,
    required this.rol,
    this.eventoAsignadoId,
    this.cambiarPass = false,
    this.activo = true,
    this.createdAt,
  });

  final String id;
  final String nombreCompleto;
  final AppRole rol;
  final String? eventoAsignadoId;
  final bool cambiarPass;
  final bool activo;
  final DateTime? createdAt;

  bool get isAdmin => rol.isAdmin;
  bool get canManageUsers => rol.canManageUsers;
  bool get canCreateContent => rol.canCreateContent;
  bool get isExterno => rol.isExterno;
  bool get usesFullShell => rol.usesFullShell;

  factory Perfil.fromMap(Map<String, dynamic> map) {
    return Perfil(
      id: map['id'] as String,
      nombreCompleto: (map['nombre_completo'] as String?) ?? 'Sin nombre',
      rol: AppRole.fromString(map['rol'] as String?),
      eventoAsignadoId: map['evento_asignado_id'] as String?,
      cambiarPass: (map['cambiar_pass'] as bool?) ?? false,
      activo: (map['activo'] as bool?) ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Perfil copyWith({
    String? nombreCompleto,
    AppRole? rol,
    String? eventoAsignadoId,
    bool? cambiarPass,
    bool? activo,
  }) {
    return Perfil(
      id: id,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      rol: rol ?? this.rol,
      eventoAsignadoId: eventoAsignadoId ?? this.eventoAsignadoId,
      cambiarPass: cambiarPass ?? this.cambiarPass,
      activo: activo ?? this.activo,
      createdAt: createdAt,
    );
  }
}
