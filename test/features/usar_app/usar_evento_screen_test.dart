import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:transworld_nexus/core/constants/app_role.dart';
import 'package:transworld_nexus/core/network/connectivity_service.dart';
import 'package:transworld_nexus/core/widgets/app_widgets.dart';
import 'package:transworld_nexus/data/models/evento.dart';
import 'package:transworld_nexus/data/models/perfil.dart';
import 'package:transworld_nexus/data/offline/sync_queue_service.dart';
import 'package:transworld_nexus/features/auth/providers/auth_providers.dart';
import 'package:transworld_nexus/features/eventos/providers/eventos_providers.dart';
import 'package:transworld_nexus/features/registrados/providers/registrados_providers.dart';
import 'package:transworld_nexus/features/usar_app/screens/usar_evento_screen.dart';

void main() {
  final evento = Evento(
    id: 'evento-1',
    nombre: 'Evento de prueba',
    fecha: DateTime(2099, 8, 20),
    lugar: 'Santiago',
  );
  const perfil = Perfil(
    id: 'admin-1',
    nombreCompleto: 'Admin Demo',
    rol: AppRole.admin,
  );

  late SharedPreferences preferences;

  setUpAll(() async {
    await initializeDateFormatting('es');
    SharedPreferences.setMockInitialValues(const {});
    preferences = await SharedPreferences.getInstance();
  });

  testWidgets('al recargar el evento el menú de acciones sigue montado', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    var bloquearRecarga = false;
    final recarga = Completer<Evento>();

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
          eventoByIdProvider.overrideWith((ref, id) async {
            if (bloquearRecarga) await recarga.future;
            return evento;
          }),
        ],
        child: const MaterialApp(
          locale: Locale('es'),
          home: UsarEventoScreen(eventoId: 'evento-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lista de asistentes registrados'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    bloquearRecarga = true;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(UsarEventoScreen)),
    );
    container.invalidate(eventoByIdProvider('evento-1'));
    await tester.pump();

    expect(find.text('Lista de asistentes registrados'), findsOneWidget);
    expect(find.byType(LoadingView), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    recarga.complete(evento);
    await tester.pumpAndSettle();
    expect(find.text('Lista de asistentes registrados'), findsOneWidget);
  });
}
