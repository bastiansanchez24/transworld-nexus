import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/constants/app_role.dart';
import 'package:transworld_nexus/core/widgets/require_permission.dart';
import 'package:transworld_nexus/data/models/perfil.dart';
import 'package:transworld_nexus/features/auth/providers/auth_providers.dart';

const _admin = Perfil(
  id: 'admin-1',
  nombreCompleto: 'Admin Demo',
  rol: AppRole.admin,
);

void main() {
  testWidgets(
    'RequireAdmin mantiene el hijo montado mientras el perfil recarga',
    (tester) async {
      var cargas = 0;
      final segundaCarga = Completer<void>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentPerfilProvider.overrideWith((ref) async {
              cargas++;
              if (cargas > 1) await segundaCarga.future;
              return _admin;
            }),
          ],
          child: MaterialApp(
            home: RequireAdmin(
              builder: (context) =>
                  const Scaffold(body: Text('formulario-activo')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('formulario-activo'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(RequireAdmin)),
      );
      container.invalidate(currentPerfilProvider);
      await tester.pump();

      // Durante la recarga debe conservar el form (skipLoadingOnReload).
      expect(find.text('formulario-activo'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      segundaCarga.complete();
      await tester.pumpAndSettle();
      expect(find.text('formulario-activo'), findsOneWidget);
    },
  );
}
