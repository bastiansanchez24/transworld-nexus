import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:transworld_nexus/core/constants/app_role.dart';
import 'package:transworld_nexus/core/network/connectivity_service.dart';
import 'package:transworld_nexus/core/widgets/nexus_components.dart';
import 'package:transworld_nexus/data/models/evento_lead.dart';
import 'package:transworld_nexus/data/models/perfil.dart';
import 'package:transworld_nexus/data/offline/sync_queue_service.dart';
import 'package:transworld_nexus/features/auth/providers/auth_providers.dart';
import 'package:transworld_nexus/features/capturador/providers/capturador_providers.dart';
import 'package:transworld_nexus/features/capturador/screens/usar_evento_lead_screen.dart';

void main() {
  final evento = EventoLead(
    id: 'campana-1',
    nombre: 'Campaña de prueba',
    fecha: DateTime(2099, 8, 20),
    pais: 'Chile',
  );
  const perfilUser = Perfil(
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

  Future<void> montar(WidgetTester tester, {required Perfil perfil}) async {
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
          eventoLeadByIdProvider.overrideWith((ref, id) async => evento),
          leadsResumenLocalProvider.overrideWith(
            (ref, id) => const LeadsResumen(total: 12, empresas: 5),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('es'),
          home: UsarEventoLeadScreen(eventoId: 'campana-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'el usuario interno ve el resumen de la campaña, no solo sus leads',
    (tester) async {
      await montar(tester, perfil: perfilUser);

      expect(find.byType(StatCard), findsNWidgets(2));
      expect(find.text('Leads capturados'), findsOneWidget);
      expect(find.text('Empresas'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Mis leads'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
