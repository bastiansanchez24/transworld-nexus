import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:transworld_nexus/core/constants/app_role.dart';
import 'package:transworld_nexus/core/network/connectivity_service.dart';
import 'package:transworld_nexus/data/models/evento.dart';
import 'package:transworld_nexus/data/models/evento_lead.dart';
import 'package:transworld_nexus/data/models/perfil.dart';
import 'package:transworld_nexus/data/offline/sync_queue_service.dart';
import 'package:transworld_nexus/features/auth/providers/auth_providers.dart';
import 'package:transworld_nexus/features/capturador/providers/capturador_providers.dart';
import 'package:transworld_nexus/features/eventos/providers/eventos_providers.dart';
import 'package:transworld_nexus/features/registrados/providers/registrados_providers.dart';
import 'package:transworld_nexus/features/usar_app/screens/usar_evento_screen.dart';

void main() {
  final evento = Evento(
    id: 'evento-1',
    nombre: 'Transworld Connect',
    fecha: DateTime(2099, 8, 20),
    lugar: 'Santiago',
  );
  final eventoLead = EventoLead.internoDesdeEvento(
    eventoOrigenId: 'evento-1',
    nombre: 'Transworld Connect',
    fecha: DateTime(2099, 8, 20),
  );
  const admin = Perfil(
    id: 'admin-1',
    nombreCompleto: 'Admin Demo',
    rol: AppRole.admin,
  );
  const usuario = Perfil(
    id: 'user-1',
    nombreCompleto: 'Usuario Interno',
    rol: AppRole.user,
  );

  late SharedPreferences preferences;

  setUpAll(() async {
    await initializeDateFormatting('es');
    SharedPreferences.setMockInitialValues(const {});
    preferences = await SharedPreferences.getInstance();
  });

  Future<void> montar(
    WidgetTester tester, {
    required Perfil perfil,
    required EventoLead? vinculado,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
          authStateChangesProvider.overrideWith(
            (ref) => const Stream<AuthState>.empty(),
          ),
          currentPerfilProvider.overrideWith((ref) async => perfil),
          registradosPorEventoProvider.overrideWith((ref, id) async => []),
          registradosResumenProvider.overrideWith(
            (ref, id) => const RegistradosResumen(
              total: 0,
              acreditados: 0,
              pendientes: 0,
            ),
          ),
          eventoByIdProvider.overrideWith((ref, id) async => evento),
          eventoLeadInternoProvider.overrideWith((ref, id) async => vinculado),
        ],
        child: const MaterialApp(
          locale: Locale('es'),
          home: UsarEventoScreen(eventoId: 'evento-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sin actividad de captura se ofrece crearla', (tester) async {
    await montar(tester, perfil: admin, vinculado: null);

    expect(find.text('Crear actividad de captura'), findsOneWidget);
    expect(find.text('Ver actividad de captura'), findsNothing);
    expect(find.text('ACCIONES DEL EVENTO'), findsOneWidget);
  });

  testWidgets('con actividad de captura se abre la existente, no se crea otra', (
    tester,
  ) async {
    await montar(tester, perfil: admin, vinculado: eventoLead);

    expect(find.text('Ver actividad de captura'), findsOneWidget);
    expect(find.text('Crear actividad de captura'), findsNothing);
  });

  testWidgets('quien no crea contenido no ve el botón de creación', (
    tester,
  ) async {
    await montar(tester, perfil: usuario, vinculado: null);

    expect(find.text('Crear actividad de captura'), findsNothing);
  });

  testWidgets('quien no crea contenido sí puede abrir la ya creada', (
    tester,
  ) async {
    await montar(tester, perfil: usuario, vinculado: eventoLead);

    expect(find.text('Ver actividad de captura'), findsOneWidget);
  });
}
