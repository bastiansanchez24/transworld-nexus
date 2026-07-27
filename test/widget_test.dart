// Smoke test mínimo. Las pantallas reales requieren un cliente Supabase
// inicializado (variables de entorno + red), por lo que las pruebas de
// integración deberían mockear los repositorios en `data/repositories/`
// en vez de levantar `TransworldNexusApp` completo acá.
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/constants/app_role.dart';

void main() {
  test('AppRole.fromString cae a "user" ante valores desconocidos', () {
    expect(AppRole.fromString('admin'), AppRole.admin);
    expect(AppRole.fromString('organizador'), AppRole.organizador);
    expect(AppRole.fromString('externo'), AppRole.externo);
    expect(AppRole.fromString('lo-que-sea'), AppRole.user);
    expect(AppRole.fromString(null), AppRole.user);
  });

  test('AppRole.fromString normaliza el rol legacy "vendedor" a user', () {
    expect(AppRole.fromString('vendedor'), AppRole.user);
  });

  test('AppRole permisos por rol', () {
    expect(AppRole.admin.isAdmin, isTrue);
    expect(AppRole.admin.canManageUsers, isTrue);
    expect(AppRole.admin.canCreateContent, isTrue);
    expect(AppRole.admin.usesFullShell, isTrue);

    expect(AppRole.organizador.canManageUsers, isFalse);
    expect(AppRole.organizador.canCreateContent, isTrue);
    expect(AppRole.organizador.usesFullShell, isTrue);

    expect(AppRole.user.canManageUsers, isFalse);
    expect(AppRole.user.canCreateContent, isFalse);
    expect(AppRole.user.usesFullShell, isTrue);

    expect(AppRole.externo.isExterno, isTrue);
    expect(AppRole.externo.canCreateContent, isFalse);
    expect(AppRole.externo.usesFullShell, isFalse);
  });

  test('AppRole.assignableRoles solo incluye roles internos', () {
    expect(
      AppRole.assignableRoles,
      [AppRole.admin, AppRole.organizador, AppRole.user],
    );
  });
}
