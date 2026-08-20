import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/constants/app_role.dart';
import 'package:transworld_nexus/core/widgets/cuenta_identity_header.dart';
import 'package:transworld_nexus/core/widgets/nexus_components.dart';
import 'package:transworld_nexus/data/models/perfil.dart';

void main() {
  testWidgets(
    'sin foto el avatar de home es círculo con dos iniciales a ras del anillo',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CuentaIdentityHeader(
              perfil: Perfil(
                id: 'user-1',
                nombreCompleto: 'Bastian Abarca',
                rol: AppRole.user,
              ),
              onAjustes: _noop,
              onMiPerfil: _noop,
            ),
          ),
        ),
      );

      expect(find.text('BA'), findsOneWidget);
      expect(find.byType(AvatarInitials), findsOneWidget);
      expect(find.byType(ClipOval), findsOneWidget);
      expect(find.text('B'), findsNothing);

      final clip = tester.getSize(find.byType(ClipOval));
      expect(clip.width, CuentaIdentityHeader.avatarSize);
      expect(clip.height, CuentaIdentityHeader.avatarSize);

      final anillo = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.shape == BoxShape.circle && d.border != null);
      expect(anillo.color, isNull);
    },
  );
}

void _noop() {}
