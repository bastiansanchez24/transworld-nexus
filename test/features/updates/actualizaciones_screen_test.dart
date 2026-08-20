import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:transworld_nexus/core/constants/app_role.dart';
import 'package:transworld_nexus/core/network/connectivity_service.dart';
import 'package:transworld_nexus/core/router/route_paths.dart';
import 'package:transworld_nexus/data/models/github_release.dart';
import 'package:transworld_nexus/data/models/perfil.dart';
import 'package:transworld_nexus/data/offline/sync_queue_service.dart';
import 'package:transworld_nexus/data/repositories/github_release_repository.dart';
import 'package:transworld_nexus/features/auth/providers/auth_providers.dart';
import 'package:transworld_nexus/features/updates/screens/actualizaciones_screen.dart';
import 'package:transworld_nexus/features/updates/services/update_platform.dart';

class _FakeGithub extends GitHubReleaseRepository {
  _FakeGithub()
    : super(
        dio: Dio(BaseOptions(baseUrl: 'http://localhost')),
        owner: 'owner',
        repo: 'repo',
      );

  @override
  Future<List<GitHubRelease>> fetchReleases({
    int perPage = 30,
    bool includePrereleases = false,
  }) async => const [];

  @override
  Future<GitHubRelease> fetchByTag(String tag) async {
    throw const GitHubReleaseException('no', statusCode: 404);
  }
}

void main() {
  testWidgets('un externo entra a Actualizaciones', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'RegisPro',
      packageName: 'cl.transworld.regispro',
      version: '1.6.8',
      buildNumber: '27',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: RoutePaths.actualizaciones,
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const SizedBox.shrink(),
          routes: [
            GoRoute(
              path: 'actualizaciones',
              builder: (_, _) => const ActualizacionesScreen(),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
          authStateChangesProvider.overrideWith(
            (ref) => const Stream<AuthState>.empty(),
          ),
          currentPerfilProvider.overrideWith(
            (ref) async => const Perfil(
              id: 'externo-1',
              nombreCompleto: 'Usuario Externo',
              rol: AppRole.externo,
            ),
          ),
          githubReleaseRepositoryProvider.overrideWithValue(_FakeGithub()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text(
        otaUpdatesSupported ? 'Actualizaciones' : 'Historial de versiones',
      ),
      findsWidgets,
    );
    expect(
      find.text('Actualizaciones solo está disponible para usuarios internos.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
