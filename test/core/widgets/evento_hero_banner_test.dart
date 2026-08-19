import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/widgets/evento_hero_banner.dart';

void main() {
  testWidgets('sin imagen usa el degradado navy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EventoHeroBanner(
            padding: EdgeInsets.all(16),
            child: Text('Evento'),
          ),
        ),
      ),
    );

    expect(find.text('Evento'), findsOneWidget);
    expect(find.byType(EventoHeroFoto), findsNothing);
    expect(find.byType(EventoHeroGradiente), findsNothing);
  });

  testWidgets('con imagen monta la foto de portada', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EventoHeroBanner(
            imagenUrl: 'https://example.com/evento.jpg',
            padding: EdgeInsets.all(16),
            child: Text('Evento'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Evento'), findsOneWidget);
    expect(find.byType(EventoHeroFoto), findsOneWidget);
  });

  testWidgets('un rebuild del padre conserva EventoHeroFoto', (tester) async {
    Widget app() => const MaterialApp(
      home: SizedBox.expand(
        child: EventoHeroFoto(
          imagenUrl: 'https://example.com/evento.jpg',
          velo: 0,
        ),
      ),
    );

    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.byType(EventoHeroFoto), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.byType(EventoHeroFoto), findsOneWidget);
  });
}
