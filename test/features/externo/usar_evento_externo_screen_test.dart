import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:transworld_nexus/core/constants/app_role.dart';
import 'package:transworld_nexus/core/network/connectivity_service.dart';
import 'package:transworld_nexus/core/widgets/evento_hero_banner.dart';
import 'package:transworld_nexus/data/models/evento.dart';
import 'package:transworld_nexus/data/models/perfil.dart';
import 'package:transworld_nexus/data/offline/sync_queue_service.dart';
import 'package:transworld_nexus/features/auth/providers/auth_providers.dart';
import 'package:transworld_nexus/features/eventos/providers/eventos_providers.dart';
import 'package:transworld_nexus/features/externo/providers/externo_dashboard_provider.dart';
import 'package:transworld_nexus/features/externo/screens/usar_evento_externo_screen.dart';
import 'package:transworld_nexus/features/registrados/providers/registrados_providers.dart';

void main() {
  final evento = Evento(
    id: 'evento-1',
    nombre: 'Evento de prueba',
    fecha: DateTime(2099, 8, 20),
    lugar: 'Santiago',
  );
  const perfil = Perfil(
    id: 'externo-1',
    nombreCompleto: 'Usuario Externo',
    rol: AppRole.externo,
    eventoAsignadoId: 'evento-1',
  );

  late SharedPreferences preferences;

  setUpAll(() async {
    await initializeDateFormatting('es');
    SharedPreferences.setMockInitialValues(const {});
    preferences = await SharedPreferences.getInstance();
  });

  Future<void> montar(
    WidgetTester tester, {
    Evento? eventoOverride,
    bool settle = true,
  }) async {
    final actual = eventoOverride ?? evento;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
          authStateChangesProvider.overrideWith(
            (ref) => const Stream<AuthState>.empty(),
          ),
          currentPerfilProvider.overrideWith((ref) async => perfil),
          externoEventosAutorizadosProvider.overrideWith(
            (ref) async => [actual],
          ),
          externoEventoBloqueadoProvider.overrideWith((ref) => false),
          eventoByIdProvider.overrideWith((ref, id) async => actual),
          registradosPorEventoProvider.overrideWith((ref, id) async => []),
          externoDashboardProvider.overrideWith(
            (ref) async => const ExternoDashboardData(
              eventosAutorizados: 1,
              leadsCapturados: 7,
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          home: UsarEventoExternoScreen(eventoId: actual.id),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('la vista externa es personal, acotada y no desborda en móvil', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await montar(tester);

    expect(find.text('Eventos con acceso'), findsOneWidget);
    expect(find.text('Leads capturados'), findsOneWidget);
    expect(find.text('Escanear QR'), findsOneWidget);
    expect(find.text('Registrar Asistente'), findsNothing);
    expect(find.text('Acreditados'), findsNothing);
    expect(find.text('Pendientes'), findsNothing);
    expect(find.byKey(const Key('externo_logout_button')), findsOneWidget);
    expect(find.byType(EventoHeroBanner), findsOneWidget);
    expect(find.byType(EventoHeroFoto), findsNothing);

    final logoutRect = tester.getRect(
      find.byKey(const Key('externo_logout_button')),
    );
    expect(logoutRect.right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('el banner superior usa la foto del evento si existe', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await montar(
      tester,
      settle: false,
      eventoOverride: Evento(
        id: evento.id,
        nombre: evento.nombre,
        fecha: evento.fecha,
        lugar: evento.lugar,
        imagenUrl: 'https://example.com/evento.jpg',
      ),
    );

    expect(find.text('Evento de prueba'), findsWidgets);
    expect(find.byType(EventoHeroBanner), findsOneWidget);
    expect(find.byType(EventoHeroFoto), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
