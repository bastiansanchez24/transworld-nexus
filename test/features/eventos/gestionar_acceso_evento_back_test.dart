import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:transworld_nexus/core/constants/app_role.dart';
import 'package:transworld_nexus/core/router/page_transitions.dart';
import 'package:transworld_nexus/core/router/route_paths.dart';
import 'package:transworld_nexus/data/models/evento.dart';
import 'package:transworld_nexus/data/models/perfil.dart';
import 'package:transworld_nexus/features/auth/providers/auth_providers.dart';
import 'package:transworld_nexus/features/eventos/providers/acceso_evento_providers.dart';
import 'package:transworld_nexus/features/eventos/providers/eventos_providers.dart';
import 'package:transworld_nexus/features/eventos/screens/gestionar_acceso_evento_screen.dart';

void main() {
  testWidgets('Android vuelve de gestión de acceso a la lista con un back', (
    tester,
  ) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = previousPlatform);

    const eventoId = 'evento-1';
    const perfil = Perfil(
      id: 'admin-1',
      nombreCompleto: 'Admin',
      rol: AppRole.admin,
    );
    final evento = Evento(
      id: eventoId,
      nombre: 'Evento de prueba',
      fecha: DateTime(2099),
    );
    final router = GoRouter(
      initialLocation: RoutePaths.eventos,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) =>
              PopScope(canPop: false, child: Scaffold(body: shell)),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.eventos,
                  builder: (_, _) => const Text('lista-eventos'),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/eventos/:id/acceso',
          pageBuilder: (_, state) => sharedAxisPage(
            key: state.pageKey,
            child: GestionarAccesoEventoScreen(
              eventoId: state.pathParameters['id']!,
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentPerfilProvider.overrideWith((ref) async => perfil),
          eventoByIdProvider.overrideWith((ref, id) async => evento),
          usuariosAsignablesAccesoProvider.overrideWith((ref) async => []),
          usuariosAutorizadosEventoProvider.overrideWith(
            (ref, id) async => <String>{},
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    router.push(RoutePaths.accesoEvento(eventoId));
    await tester.pumpAndSettle();

    expect(find.text('Acceso al evento'), findsOneWidget);
    expect(find.byType(BackButtonListener), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/eventos');
    expect(find.text('lista-eventos'), findsOneWidget);
    expect(find.text('Acceso al evento'), findsNothing);
    debugDefaultTargetPlatformOverride = previousPlatform;
  });
}
