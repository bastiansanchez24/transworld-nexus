import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/constants/app_role.dart';

void main() {
  test(
    'solo administrador y organizador pueden exportar y ver leads globales',
    () {
      for (final role in [AppRole.admin, AppRole.organizador]) {
        expect(role.canExportData, isTrue, reason: role.value);
        expect(role.canViewAllLeads, isTrue, reason: role.value);
      }

      for (final role in [AppRole.user, AppRole.externo]) {
        expect(role.canExportData, isFalse, reason: role.value);
        expect(role.canViewAllLeads, isFalse, reason: role.value);
        expect(role.requiresEventAssignment, isTrue, reason: role.value);
      }

      for (final role in [AppRole.admin, AppRole.organizador]) {
        expect(role.requiresEventAssignment, isFalse, reason: role.value);
      }
    },
  );
}
