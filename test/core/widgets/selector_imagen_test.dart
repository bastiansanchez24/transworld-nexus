import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_symbols_icons/symbols.dart';
import 'package:transworld_nexus/core/widgets/nexus_components.dart';
import 'package:transworld_nexus/core/widgets/selector_imagen.dart';

Uint8List _jpegDePrueba() {
  final imagen = img.Image(width: 8, height: 8);
  img.fill(imagen, color: img.ColorRgb8(20, 80, 127));
  return img.encodeJpg(imagen);
}

Future<void> _montar(WidgetTester tester, Widget selector) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: selector)),
    ),
  );
}

/// Ancho disponible dentro del formulario de un teléfono (375 - 20 - 20).
Future<void> _montarEnFormulario(WidgetTester tester, Widget selector) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 335, child: selector)),
      ),
    ),
  );
}

void main() {
  testWidgets('sin imagen invita a agregarla', (tester) async {
    await _montar(
      tester,
      SelectorImagen(onElegir: () {}, etiquetaVacio: 'Agregar foto del lead'),
    );

    expect(find.byType(DashedBorderBox), findsOneWidget);
    expect(find.text('Agregar foto del lead'), findsOneWidget);
    // Sin imagen no hay nada que quitar.
    expect(find.byIcon(Symbols.close_rounded), findsNothing);
  });

  testWidgets('con bytes muestra la imagen y el botón de quitar', (
    tester,
  ) async {
    var quitados = 0;
    await _montar(
      tester,
      SelectorImagen(
        bytes: _jpegDePrueba(),
        onElegir: () {},
        onQuitar: () => quitados++,
      ),
    );
    await tester.pump();

    expect(find.byType(DashedBorderBox), findsNothing);
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.byIcon(Symbols.close_rounded));
    expect(quitados, 1);
  });

  testWidgets('deshabilitado no ofrece quitar la imagen', (tester) async {
    await _montar(
      tester,
      SelectorImagen(
        bytes: _jpegDePrueba(),
        enabled: false,
        onElegir: () {},
        onQuitar: () {},
      ),
    );
    await tester.pump();

    expect(find.byIcon(Symbols.close_rounded), findsNothing);
  });

  testWidgets('la foto del lead es cuadrada y acotada', (tester) async {
    await _montarEnFormulario(
      tester,
      SelectorImagen(
        bytes: _jpegDePrueba(),
        aspectRatio: 1,
        anchoMaximo: kAnchoSelectorFotoLead,
        onElegir: () {},
      ),
    );
    await tester.pump();

    final caja = tester.getSize(find.byType(AspectRatio));
    expect(caja, const Size(kAnchoSelectorFotoLead, kAnchoSelectorFotoLead));
  });

  testWidgets('la imagen del evento es 16:9 y más ancha que la del lead', (
    tester,
  ) async {
    await _montarEnFormulario(
      tester,
      SelectorImagen(
        bytes: _jpegDePrueba(),
        anchoMaximo: kAnchoSelectorImagenEvento,
        onElegir: () {},
      ),
    );
    await tester.pump();

    final caja = tester.getSize(find.byType(AspectRatio));
    expect(caja.width, kAnchoSelectorImagenEvento);
    expect(caja.width / caja.height, closeTo(16 / 9, 0.001));
    expect(kAnchoSelectorImagenEvento, greaterThan(kAnchoSelectorFotoLead));
  });

  // El formulario llega a 720 px de ancho en web: sin tope, el recuadro se
  // estiraría de lado a lado.
  testWidgets('no se estira en pantallas anchas', (tester) async {
    await _montar(
      tester,
      SizedBox(
        width: 720,
        child: SelectorImagen(
          bytes: _jpegDePrueba(),
          aspectRatio: 1,
          anchoMaximo: kAnchoSelectorFotoLead,
          onElegir: () {},
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byType(AspectRatio)).width,
      kAnchoSelectorFotoLead,
    );
  });

  testWidgets('el recuadro vacío también respeta proporción y ancho', (
    tester,
  ) async {
    await _montarEnFormulario(
      tester,
      SelectorImagen(
        aspectRatio: 1,
        anchoMaximo: kAnchoSelectorFotoLead,
        onElegir: () {},
      ),
    );

    final caja = tester.getSize(find.byType(DashedBorderBox));
    expect(caja, const Size(kAnchoSelectorFotoLead, kAnchoSelectorFotoLead));
  });

  testWidgets('muestra el aviso de foto pendiente bajo la imagen', (
    tester,
  ) async {
    await _montar(
      tester,
      SelectorImagen(
        bytes: _jpegDePrueba(),
        onElegir: () {},
        pieDeFoto: const StatusChip(
          label: 'Foto pendiente de subir',
          variant: StatusChipVariant.warning,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Foto pendiente de subir'), findsOneWidget);
  });
}
