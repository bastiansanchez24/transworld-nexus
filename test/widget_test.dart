// Smoke test mínimo. Las pantallas reales requieren un cliente Supabase
// inicializado (variables de entorno + red), por lo que las pruebas de
// integración deberían mockear los repositorios en `data/repositories/`
// en vez de levantar `TransworldNexusApp` completo acá.
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/constants/app_role.dart';

void main() {
  test('AppRole.fromString cae a "user" ante valores desconocidos', () {
    expect(AppRole.fromString('admin'), AppRole.admin);
    expect(AppRole.fromString('lo-que-sea'), AppRole.user);
    expect(AppRole.fromString(null), AppRole.user);
  });

  test('AppRole.isAdmin solo es true para admin', () {
    expect(AppRole.admin.isAdmin, isTrue);
    expect(AppRole.vendedor.isAdmin, isFalse);
    expect(AppRole.user.isAdmin, isFalse);
  });
}
