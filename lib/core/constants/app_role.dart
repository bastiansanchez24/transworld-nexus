/// Roles de negocio de la aplicación.
///
/// En el proyecto legado el control de acceso por rol vivía únicamente en
/// condicionales de UI (`rol === 'admin'` repetido en decenas de archivos,
/// ver documentacion_zips_registro_pro.md Sección 17.6) y la base de datos
/// no lo hacía cumplir. Acá seguimos necesitando estas comprobaciones en la
/// UI para una buena experiencia (ocultar botones que de todas formas
/// fallarían), pero la aplicación real de la regla vive en `supabase/schema.sql`
/// (RLS + trigger anti-escalación). Este enum es solo el reflejo tipado en
/// el cliente de esa misma regla de negocio.
enum AppRole {
  admin('admin'),
  vendedor('vendedor'),
  user('user');

  const AppRole(this.value);

  final String value;

  static AppRole fromString(String? raw) {
    return AppRole.values.firstWhere(
      (r) => r.value == raw,
      orElse: () => AppRole.user,
    );
  }

  bool get isAdmin => this == AppRole.admin;

  String get label => switch (this) {
        AppRole.admin => 'Administrador',
        AppRole.vendedor => 'Vendedor',
        AppRole.user => 'Usuario',
      };
}
