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

  test('el usuario interno ve todos los leads; el externo solo los suyos', () {
    for (final role in [AppRole.admin, AppRole.organizador, AppRole.user]) {
      expect(role.canViewAllLeads, isTrue, reason: role.value);
    }
    expect(AppRole.externo.canViewAllLeads, isFalse);
  });

  test(
    'editar leads ajenos y ver su contacto queda en administrador y organizador',
    () {
      for (final role in [AppRole.admin, AppRole.organizador]) {
        expect(role.canEditAnyLead, isTrue, reason: role.value);
        expect(role.canViewLeadContactData, isTrue, reason: role.value);
      }

      for (final role in [AppRole.user, AppRole.externo]) {
        expect(role.canEditAnyLead, isFalse, reason: role.value);
        expect(role.canViewLeadContactData, isFalse, reason: role.value);
      }
    },
  );
}
