import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/widgets/app_network_image.dart';
import 'package:transworld_nexus/core/widgets/evento_hero_banner.dart';

void main() {
  testWidgets('monta Image.network y sobrevive un rebuild del padre', (
    tester,
  ) async {
    Widget app() => const MaterialApp(
      home: SizedBox.expand(
        child: AppNetworkImage(
          url: 'https://example.com/foto.jpg',
          placeholder: SizedBox(key: Key('placeholder')),
        ),
      ),
    );

    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.byType(AppNetworkImage), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.byType(AppNetworkImage), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('la portada del evento usa el mismo widget de red', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.expand(
          child: EventoHeroFoto(
            imagenUrl: 'https://example.com/evento.jpg',
            velo: 0,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppNetworkImage), findsOneWidget);
  });
}
