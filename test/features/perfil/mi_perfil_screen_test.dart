import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:transworld_nexus/core/constants/app_role.dart';
import 'package:transworld_nexus/core/network/connectivity_service.dart';
import 'package:transworld_nexus/core/widgets/tw_components.dart';
import 'package:transworld_nexus/data/models/perfil.dart';
import 'package:transworld_nexus/data/offline/sync_queue_service.dart';
import 'package:transworld_nexus/data/repositories/auth_repository.dart';
import 'package:transworld_nexus/features/auth/providers/auth_providers.dart';
import 'package:transworld_nexus/features/perfil/providers/perfil_providers.dart';
import 'package:transworld_nexus/features/perfil/screens/mi_perfil_screen.dart';

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository()
    : super(
        SupabaseClient(
          'http://localhost',
          'fake-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  String? nombreGuardado;
  String? passwordGuardada;

  @override
  String? get emailSesionActual => 'demo@transworld.cl';

  @override
  Future<void> actualizarNombrePropio(String nuevoNombre) async {
    nombreGuardado = nuevoNombre;
  }

  @override
  Future<void> forzarNuevaContrasena(String nuevaContrasena) async {
    passwordGuardada = nuevaContrasena;
  }
}

const _perfil = Perfil(
  id: 'perfil-1',
  nombreCompleto: 'Ana Demo',
  rol: AppRole.organizador,
);

Future<void> _montar(WidgetTester tester, FakeAuthRepository repo) async {
  // Viewport alto: el ListView solo construye lo que cabe en pantalla y la
  // card de datos vive al final, debajo de los KPI y del detalle de leads.
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final router = GoRouter(
    initialLocation: '/perfil',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const SizedBox.shrink(),
        routes: [
          GoRoute(path: 'perfil', builder: (_, _) => const MiPerfilScreen()),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
        authRepositoryProvider.overrideWithValue(repo),
        currentPerfilProvider.overrideWith((ref) async => _perfil),
        miPerfilStatsProvider.overrideWith(
          (ref) async => const MiPerfilStats(
            leadsCapturados: 0,
            asistentesRegistrados: 0,
            acreditaciones: 0,
            eventosCreados: 0,
          ),
        ),
        misLeadsProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp.router(
        locale: const Locale('es'),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();

  // La card "Mis Datos de Usuario" arranca colapsada.
  await tester.tap(find.text('Mis Datos de Usuario'));
  await tester.pumpAndSettle();
}

Finder get _campoPassword =>
    find.widgetWithText(TextFormField, 'Escribe una nueva contraseña');

Future<void> _guardar(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Guardar cambios'));
  await tester.tap(find.text('Guardar cambios'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el campo contraseña aparece bajo el correo', (tester) async {
    await _montar(tester, FakeAuthRepository());

    expect(_campoPassword, findsOneWidget);
    expect(
      tester.getTopLeft(_campoPassword).dy,
      greaterThan(
        tester
            .getTopLeft(
              find.widgetWithText(TextFormField, 'Correo de la cuenta'),
            )
            .dy,
      ),
    );
  });

  testWidgets('dejarla en blanco guarda el nombre sin tocar la contraseña', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await _montar(tester, repo);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tu nombre completo'),
      'Ana Editada',
    );
    await _guardar(tester);

    expect(repo.nombreGuardado, 'Ana Editada');
    expect(repo.passwordGuardada, isNull);
  });

  testWidgets('una contraseña débil bloquea el guardado', (tester) async {
    final repo = FakeAuthRepository();
    await _montar(tester, repo);

    await tester.enterText(_campoPassword, 'abc12345');
    await _guardar(tester);

    expect(find.text('Debe incluir una mayúscula'), findsOneWidget);
    expect(repo.passwordGuardada, isNull);
    expect(repo.nombreGuardado, isNull);
  });

  testWidgets('una contraseña fuerte se envía y el campo se limpia', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await _montar(tester, repo);

    await tester.enterText(_campoPassword, 'Abcd12#x');
    await _guardar(tester);

    expect(repo.passwordGuardada, 'Abcd12#x');
    expect(repo.nombreGuardado, 'Ana Demo');
    expect(
      tester.widget<TextFormField>(_campoPassword).controller?.text,
      isEmpty,
    );
  });

  testWidgets('el ojo de la contraseña no queda pegado al borde del campo', (
    tester,
  ) async {
    await _montar(tester, FakeAuthRepository());

    final ojo = find.descendant(
      of: _campoPassword,
      matching: find.byType(TwPasswordEye),
    );
    expect(ojo, findsOneWidget);

    final margen =
        tester.getTopRight(_campoPassword).dx - tester.getTopRight(ojo).dx;
    expect(
      margen,
      closeTo(14, 0.5),
      reason:
          'el `suffixIcon` ignora el contentPadding del tema; sin relleno '
          'propio el icono toca el borde',
    );
  });
}
