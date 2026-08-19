import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/features/capturador/widgets/foto_lead_identidad.dart';

/// PNG 1x1 válido: alcanza para que `Image.memory` decodifique en el test.
final _pngMinimo = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

void main() {
  Future<void> montar(
    WidgetTester tester, {
    Uint8List? bytes,
    required VoidCallback onElegir,
    VoidCallback? onQuitar,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: FotoLeadAvatar(
              bytes: bytes,
              onElegir: onElegir,
              onQuitar: onQuitar,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('sin foto el toque abre el selector directamente', (
    tester,
  ) async {
    var elegidas = 0;
    await montar(tester, onElegir: () => elegidas++);

    await tester.tap(find.byKey(const Key('lead_foto_avatar')));
    await tester.pumpAndSettle();

    expect(elegidas, 1);
    expect(find.text('Ver foto'), findsNothing);
  });

  testWidgets('con foto ofrece ver, cambiar y eliminar', (tester) async {
    await montar(tester, bytes: _pngMinimo, onElegir: () {}, onQuitar: () {});

    await tester.tap(find.byKey(const Key('lead_foto_avatar')));
    await tester.pumpAndSettle();

    expect(find.text('Ver foto'), findsOneWidget);
    expect(find.text('Cambiar Foto'), findsOneWidget);
    expect(find.text('Eliminar Foto'), findsOneWidget);
  });

  testWidgets('sin forma de quitarla no se ofrece eliminar', (tester) async {
    await montar(tester, bytes: _pngMinimo, onElegir: () {});

    await tester.tap(find.byKey(const Key('lead_foto_avatar')));
    await tester.pumpAndSettle();

    expect(find.text('Ver foto'), findsOneWidget);
    expect(find.text('Eliminar Foto'), findsNothing);
  });

  testWidgets('"Ver foto" abre el visor y se cierra al tocar el fondo', (
    tester,
  ) async {
    await montar(tester, bytes: _pngMinimo, onElegir: () {}, onQuitar: () {});

    await tester.tap(find.byKey(const Key('lead_foto_avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lead_foto_ver')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lead_foto_visor')), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lead_foto_visor')), findsNothing);
  });

  testWidgets('"Cambiar Foto" y "Eliminar Foto" avisan a la pantalla', (
    tester,
  ) async {
    var elegidas = 0;
    var quitadas = 0;
    await montar(
      tester,
      bytes: _pngMinimo,
      onElegir: () => elegidas++,
      onQuitar: () => quitadas++,
    );

    await tester.tap(find.byKey(const Key('lead_foto_avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lead_foto_cambiar')));
    await tester.pumpAndSettle();
    expect(elegidas, 1);

    await tester.tap(find.byKey(const Key('lead_foto_avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lead_foto_eliminar')));
    await tester.pumpAndSettle();
    expect(quitadas, 1);
  });
}
