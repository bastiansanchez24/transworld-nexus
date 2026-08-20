import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/constants/app_role.dart';

void main() {
  test('solo administrador y organizador pueden exportar', () {
    for (final role in [AppRole.admin, AppRole.organizador]) {
      expect(role.canExportData, isTrue, reason: role.value);
      expect(role.requiresEventAssignment, isFalse, reason: role.value);
    }

    for (final role in [AppRole.user, AppRole.externo]) {
      expect(role.canExportData, isFalse, reason: role.value);
      expect(role.requiresEventAssignment, isTrue, reason: role.value);
    }
  });

  test('cualquier rol autenticado ve todos los leads de su campaña', () {
    for (final role in AppRole.values) {
      expect(role.canViewAllLeads, isTrue, reason: role.value);
    }
  });

  test(
    'editar leads ajenos y ver el contacto queda en administrador y organizador',
    () {
      for (final role in [AppRole.admin, AppRole.organizador]) {
        expect(role.canEditAnyLead, isTrue, reason: role.value);
        expect(role.canViewContactData, isTrue, reason: role.value);
      }

      for (final role in [AppRole.user, AppRole.externo]) {
        expect(role.canEditAnyLead, isFalse, reason: role.value);
        expect(role.canViewContactData, isFalse, reason: role.value);
      }
    },
  );

  test('cualquier rol autenticado puede ver actualizaciones', () {
    for (final role in AppRole.values) {
      expect(role.canAccessAppUpdates, isTrue, reason: role.value);
    }
  });
}
