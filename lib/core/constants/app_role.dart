/// Roles globales de la aplicación.
enum AppRole {
  admin('admin'),
  organizador('organizador'),
  user('user'),
  externo('externo');

  const AppRole(this.value);

  final String value;

  /// Roles asignables al crear un usuario (admin).
  static const creatableRoles = [
    AppRole.admin,
    AppRole.organizador,
    AppRole.user,
    AppRole.externo,
  ];

  /// Roles asignables al editar un usuario interno (externo solo vía creación).
  static const assignableRoles = [
    AppRole.admin,
    AppRole.organizador,
    AppRole.user,
  ];

  static AppRole fromString(String? raw) {
    if (raw == null || raw.isEmpty) return AppRole.user;
    if (raw == 'vendedor') return AppRole.user;
    return AppRole.values.firstWhere(
      (r) => r.value == raw,
      orElse: () => AppRole.user,
    );
  }

  bool get isAdmin => this == AppRole.admin;
  bool get isOrganizador => this == AppRole.organizador;
  bool get isUsuario => this == AppRole.user;
  bool get isExterno => this == AppRole.externo;

  bool get canManageUsers => isAdmin;
  bool get requiresEventAssignment => isUsuario || isExterno;
  bool get canCreateContent => isAdmin || isOrganizador;
  bool get canRegisterAttendees => !isExterno;
  bool get canAccessNotifications => !isExterno;
  bool get canExportData => isAdmin || isOrganizador;

  /// Todos los roles autenticados ven el listado de la campaña que pueden
  /// abrir. El externo queda acotado por RLS a sus eventos asignados.
  bool get canViewAllLeads => true;

  /// Editar leads de cualquier capturador. Sin esto solo se editan los propios.
  bool get canEditAnyLead => isAdmin || isOrganizador;

  /// Ver sin enmascarar el email y el teléfono de leads y registrados.
  bool get canViewContactData => isAdmin || isOrganizador;

  bool get usesFullShell => !isExterno;

  /// Actualizaciones OTA / historial de versiones: cualquier sesión autenticada.
  bool get canAccessAppUpdates => true;

  String get label => switch (this) {
    AppRole.admin => 'Administrador',
    AppRole.organizador => 'Organizador',
    AppRole.user => 'Usuario',
    AppRole.externo => 'Usuario Externo',
  };
}
