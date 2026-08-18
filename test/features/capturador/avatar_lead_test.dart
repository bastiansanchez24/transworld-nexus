import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:transworld_nexus/core/widgets/nexus_components.dart';
import 'package:transworld_nexus/data/models/lead.dart';
import 'package:transworld_nexus/data/offline/pending_photo_store.dart';
import 'package:transworld_nexus/features/capturador/widgets/avatar_lead.dart';

Lead _lead({List<String> fotos = const []}) => Lead(
      id: 'lead-1',
      eventoId: 'evento-1',
      nombreCompleto: 'María González',
      fotosUrls: fotos,
    );

Future<void> _montar(
  WidgetTester tester,
  Lead lead, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(body: Center(child: AvatarLead(lead: lead))),
      ),
    ),
  );
}

void main() {
  testWidgets('sin foto muestra las iniciales', (tester) async {
    await _montar(tester, _lead());

    expect(find.byType(AvatarInitials), findsOneWidget);
    expect(find.text('MG'), findsOneWidget);
  });

  testWidgets('con una foto pendiente en disco la pinta en círculo',
      (tester) async {
    final bytes = img.encodeJpg(img.Image(width: 8, height: 8));
    const marcador = '$fotoLocalPrefix/tmp/leads_pendientes/a.jpg';

    await _montar(
      tester,
      _lead(fotos: const [marcador]),
      overrides: [
        fotoPendienteBytesProvider(marcador).overrideWith((ref) async => bytes),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(ClipOval), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(AvatarInitials), findsNothing);
  });

  // El archivo puede haberse perdido (datos limpiados, o el sistema recuperó
  // espacio): la lista tiene que seguir siendo legible.
  testWidgets('si la foto pendiente ya no está, vuelve a las iniciales',
      (tester) async {
    const marcador = '$fotoLocalPrefix/tmp/leads_pendientes/b.jpg';

    await _montar(
      tester,
      _lead(fotos: const [marcador]),
      overrides: [
        fotoPendienteBytesProvider(marcador).overrideWith((ref) async => null),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(AvatarInitials), findsOneWidget);
  });
}
