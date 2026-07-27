import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/acreditacion/screens/acreditar_confirmado_screen.dart';
import '../../features/acreditacion/screens/acreditar_qr_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/recrear_pass_screen.dart';
import '../../features/auth/screens/recuperar_password_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/capturador/screens/crear_editar_evento_lead_screen.dart';
import '../../features/capturador/screens/crear_lead_screen.dart';
import '../../features/capturador/screens/exportar_leads_screen.dart';
import '../../features/capturador/screens/lista_leads_screen.dart';
import '../../features/capturador/screens/listar_eventos_leads_screen.dart';
import '../../features/capturador/screens/usar_evento_lead_screen.dart';
import '../../data/models/capturar_lead_route_extra.dart';
import '../../features/eventos/screens/crear_editar_evento_screen.dart';
import '../../features/eventos/screens/listar_eventos_screen.dart';
import '../../features/exportacion/screens/exportar_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/kpi/screens/kpi_screen.dart';
import '../../features/perfil/screens/mi_perfil_screen.dart';
import '../../features/updates/screens/actualizaciones_screen.dart';
import '../../features/registrados/screens/editar_registrado_screen.dart';
import '../../features/registrados/screens/ver_registrados_screen.dart';
import '../../features/registro/screens/registrar_confirmado_screen.dart';
import '../../features/registro/screens/registro_por_cliente_screen.dart';
import '../../features/registro_publico/screens/registro_publico_screen.dart';
import '../../features/externo/screens/evento_finalizado_screen.dart';
import '../../features/externo/screens/usar_evento_externo_screen.dart';
import '../../features/usar_app/screens/usar_evento_screen.dart';
import '../../features/usuarios/screens/editar_usuario_screen.dart';
import '../../features/usuarios/screens/gestionar_usuarios_screen.dart';
import '../../features/usuarios/screens/nuevo_usuario_screen.dart';
import 'go_router_refresh_stream.dart';
import 'page_transitions.dart';
import 'route_paths.dart';
import '../widgets/main_shell_scaffold.dart';

/// Rutas que no requieren sesión iniciada.
bool _esRutaPublica(String location) {
  return location == RoutePaths.login ||
      location == RoutePaths.recuperarPassword ||
      location == RoutePaths.registroForms ||
      location == RoutePaths.eventoFinalizado;
}

/// Captura de lead desde el escáner QR (`/capturador/:id/capturar`).
bool _esRutaCapturarLead(String location) {
  final parts = location.split('/');
  // ['', 'capturador', ':id', 'capturar']
  return parts.length == 4 &&
      parts[1] == 'capturador' &&
      parts[3] == 'capturar' &&
      parts[2].isNotEmpty;
}

bool _rutaPermitidaExterno(
  String location,
  Set<String> eventoIds, {
  String? desdeEventoCaptura,
}) {
  for (final eventoId in eventoIds) {
    if (location == RoutePaths.externoEvento(eventoId)) return true;
    if (location == RoutePaths.acreditarQr(eventoId)) return true;
    if (location == RoutePaths.registrar(eventoId)) return true;
    if (location == RoutePaths.registroPorCliente(eventoId)) return true;
  }
  // Solo permitir capturar lead si viene amarrado a un evento autorizado.
  if (_esRutaCapturarLead(location)) {
    return desdeEventoCaptura != null &&
        desdeEventoCaptura.isNotEmpty &&
        eventoIds.contains(desdeEventoCaptura);
  }
  return false;
}

/// Extrae el id de evento de rutas operativas `/externo/eventos/:id` o
/// `/eventos/:id/...`.
String? _eventoIdDeRutaOperativa(String location) {
  final parts = location.split('/');
  if (parts.length >= 4 &&
      parts[1] == 'externo' &&
      parts[2] == 'eventos' &&
      parts[3].isNotEmpty) {
    return parts[3];
  }
  if (parts.length >= 3 && parts[1] == 'eventos' && parts[2].isNotEmpty) {
    return parts[2];
  }
  return null;
}

bool _esRutaShell(String location) {
  return location == RoutePaths.home ||
      location == RoutePaths.eventos ||
      location == RoutePaths.capturador ||
      location == RoutePaths.usuarios;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authClient = Supabase.instance.client.auth;

  final refreshListenable = GoRouterRefreshStream(authClient.onAuthStateChange);
  ref.onDispose(refreshListenable.dispose);
  // El redirect también depende del perfil de negocio (cambiar_pass), que
  // llega de forma asíncrona después del login: re-evaluar al resolverse.
  ref.listen(currentPerfilProvider, (_, _) => refreshListenable.refresh());
  ref.listen(externoEventoProvider, (_, _) => refreshListenable.refresh());
  ref.listen(
    externoEventosAutorizadosProvider,
    (_, _) => refreshListenable.refresh(),
  );
  ref.listen(
    externoEventoActivoOverrideProvider,
    (_, _) => refreshListenable.refresh(),
  );

  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final location = state.matchedLocation;

      // Compatibilidad con enlaces antiguos compartidos como /#/r/:eventoId.
      if (location.startsWith('/r/')) {
        final eventoId = state.pathParameters['eventoId'];
        if (eventoId != null && eventoId.isNotEmpty) {
          return RoutePaths.registroPublico(eventoId);
        }
      }

      final session = authClient.currentSession;
      final esPublica = _esRutaPublica(location);
      final enSplash = location == RoutePaths.splash;

      if (session == null && !esPublica) {
        return RoutePaths.login;
      }

      final perfilAsync = ref.read(currentPerfilProvider);
      final perfil = perfilAsync.valueOrNull;

      // Perfil aún no resuelto: no abrir shell ni mostrar login.
      // - isLoading: splash
      // - hasError: sin fila / fallo de red → cerrar sesión → login
      if (session != null && perfil == null && !esPublica && !enSplash) {
        if (perfilAsync.hasError && !perfilAsync.isLoading) {
          Future.microtask(() => authClient.signOut());
          return RoutePaths.login;
        }
        return RoutePaths.splash;
      }

      if (session != null && (location == RoutePaths.login || enSplash)) {
        if (perfil == null) {
          if (perfilAsync.hasError && !perfilAsync.isLoading) {
            Future.microtask(() => authClient.signOut());
            return RoutePaths.login;
          }
          // Sesión viva, perfil cargando: quedarse en splash (no en login).
          return enSplash ? null : RoutePaths.splash;
        }
        if (perfil.isExterno) {
          final eventoId = ref.read(externoEventoIdProvider);
          if (eventoId == null || eventoId.isEmpty) {
            return RoutePaths.eventoFinalizado;
          }
          return RoutePaths.externoEvento(eventoId);
        }
        return RoutePaths.home;
      }

      if (session != null && perfil != null && !perfil.activo) {
        authClient.signOut();
        return RoutePaths.login;
      }

      if (session != null &&
          perfil != null &&
          perfil.cambiarPass &&
          !esPublica &&
          location != RoutePaths.recrearPass) {
        return RoutePaths.recrearPass;
      }

      if (session != null && perfil != null && perfil.isExterno) {
        final autorizadosIds = ref.read(externoEventosAutorizadosIdsProvider);
        final preferidoCarga = ref.read(externoEventoIdProvider) ??
            perfil.eventoAsignadoId;
        final holdExterno = preferidoCarga != null && preferidoCarga.isNotEmpty
            ? RoutePaths.externoEvento(preferidoCarga)
            : RoutePaths.eventoFinalizado;

        // null = lista aún cargando: no abrir shell ni capturador libre.
        if (autorizadosIds == null) {
          if (preferidoCarga != null && preferidoCarga.isNotEmpty) {
            if (location == RoutePaths.externoEvento(preferidoCarga) ||
                location == RoutePaths.acreditarQr(preferidoCarga) ||
                location == RoutePaths.registrar(preferidoCarga) ||
                location == RoutePaths.registroPorCliente(preferidoCarga)) {
              return null;
            }
            if (_esRutaCapturarLead(location) &&
                state.uri.queryParameters['desdeEvento'] == preferidoCarga) {
              return null;
            }
          }
          if (location == RoutePaths.eventoFinalizado) return null;
          return holdExterno;
        }

        final eventoId = ref.read(externoEventoIdProvider);
        if (eventoId == null || eventoId.isEmpty) {
          if (location != RoutePaths.eventoFinalizado) {
            return RoutePaths.eventoFinalizado;
          }
          return null;
        }

        final sinOperables = ref.read(externoSinEventosOperablesProvider);
        if (sinOperables == null) {
          final desdeEvento = state.uri.queryParameters['desdeEvento'];
          if (_rutaPermitidaExterno(
            location,
            {eventoId},
            desdeEventoCaptura: desdeEvento,
          )) {
            return null;
          }
          if (location == RoutePaths.eventoFinalizado) {
            return RoutePaths.externoEvento(eventoId);
          }
          return RoutePaths.externoEvento(eventoId);
        }
        if (sinOperables) {
          if (location != RoutePaths.eventoFinalizado) {
            return RoutePaths.eventoFinalizado;
          }
          return null;
        }

        // Activo no operable pero hay alternativas → ir al primero operable.
        final primerOperable = ref.read(externoPrimerEventoOperableIdProvider);
        final activoAsync = ref.read(externoEventoProvider);
        final activo = activoAsync.valueOrNull;
        if (primerOperable != null &&
            activo != null &&
            !eventoExternoOperable(activo) &&
            primerOperable != eventoId) {
          return RoutePaths.externoEvento(primerOperable);
        }

        if (location == RoutePaths.eventoFinalizado) {
          return RoutePaths.externoEvento(eventoId);
        }

        final idsPermitidos = autorizadosIds.isEmpty
            ? {eventoId}
            : autorizadosIds;

        final desdeEventoCaptura =
            state.uri.queryParameters['desdeEvento'];

        // Ruta operativa con id no autorizado → activo.
        final idEnRuta = _eventoIdDeRutaOperativa(location);
        if (idEnRuta != null &&
            !idsPermitidos.contains(idEnRuta) &&
            !_esRutaCapturarLead(location)) {
          return RoutePaths.externoEvento(eventoId);
        }

        final permitida = _rutaPermitidaExterno(
          location,
          idsPermitidos,
          desdeEventoCaptura: desdeEventoCaptura,
        );

        if (permitida) {
          return null;
        }

        if (location.startsWith('/externo/')) {
          return RoutePaths.externoEvento(eventoId);
        }

        for (final id in idsPermitidos) {
          if (location.startsWith('/eventos/$id/')) {
            return RoutePaths.externoEvento(eventoId);
          }
        }

        if (_esRutaShell(location) ||
            location == RoutePaths.perfil ||
            location == RoutePaths.actualizaciones ||
            location == RoutePaths.capturador ||
            location.startsWith('/capturador') ||
            location.startsWith('/usuarios') ||
            location == RoutePaths.crearEvento ||
            location == RoutePaths.crearEventoLead) {
          return RoutePaths.externoEvento(eventoId);
        }

        if (location.startsWith('/eventos/')) {
          return RoutePaths.externoEvento(eventoId);
        }

        if (location == RoutePaths.home) {
          return RoutePaths.externoEvento(eventoId);
        }

        return null;
      }

      if (session != null &&
          perfil != null &&
          !perfil.canManageUsers &&
          (location == RoutePaths.usuarios ||
              location.startsWith('/usuarios/'))) {
        return RoutePaths.home;
      }

      if (session != null &&
          perfil != null &&
          perfil.usesFullShell &&
          location.startsWith('/externo/')) {
        return RoutePaths.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.recuperarPassword,
        builder: (context, state) => const RecuperarPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.recrearPass,
        builder: (context, state) => const RecrearPassScreen(),
      ),
      GoRoute(
        path: RoutePaths.eventoFinalizado,
        builder: (context, state) => const EventoFinalizadoScreen(),
      ),
      GoRoute(
        path: '/externo/eventos/:id',
        builder: (context, state) => UsarEventoExternoScreen(
          eventoId: state.pathParameters['id']!,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.eventos,
                builder: (context, state) => const ListarEventosScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.capturador,
                builder: (context, state) => const ListarEventosLeadsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.usuarios,
                builder: (context, state) => const GestionarUsuariosScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.crearEvento,
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: const CrearEditarEventoScreen(),
        ),
      ),
      GoRoute(
        path: '/eventos/:id/editar',
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: CrearEditarEventoScreen(
            eventoId: state.pathParameters['id'],
          ),
        ),
      ),
      GoRoute(
        path: '/eventos/:id/usar',
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: UsarEventoScreen(
            eventoId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/eventos/:id/registrar',
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: RegistrarConfirmadoScreen(
            eventoId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/eventos/:id/registro-cliente',
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: RegistroPorClienteScreen(
            eventoId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/eventos/:id/acreditar',
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: AcreditarConfirmadoScreen(
            eventoId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/eventos/:id/acreditar-qr',
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: AcreditarQrScreen(
            eventoId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/eventos/:id/registrados',
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: VerRegistradosScreen(
            eventoId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/eventos/:eventoId/registrados/:registradoId/editar',
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: EditarRegistradoScreen(
            eventoId: state.pathParameters['eventoId']!,
            registradoId: state.pathParameters['registradoId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/eventos/:id/kpi',
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: KpiScreen(
            eventoId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/eventos/:id/exportar',
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: ExportarScreen(
            eventoId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.crearEventoLead,
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: const CrearEditarEventoLeadScreen(),
        ),
      ),
      GoRoute(
        path: '/capturador/:id/editar',
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: CrearEditarEventoLeadScreen(
            eventoId: state.pathParameters['id'],
          ),
        ),
      ),
      GoRoute(
        path: '/capturador/:id/usar',
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: UsarEventoLeadScreen(
            eventoId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/capturador/:id/capturar',
        pageBuilder: (context, state) {
          final routeExtra = CapturarLeadRouteExtra.from(state.extra);
          final desdeEvento = state.uri.queryParameters['desdeEvento'];
          return sharedAxisPage(
            key: state.pageKey,
            child: CrearLeadScreen(
              eventoId: state.pathParameters['id']!,
              prefill: routeExtra.prefill,
              eventoRegistroId:
                  routeExtra.eventoRegistroId ?? desdeEvento,
            ),
          );
        },
      ),
      GoRoute(
        path: '/capturador/:id/leads',
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: ListaLeadsScreen(
            eventoId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/capturador/:eventoId/leads/:leadId',
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: DetalleLeadScreen(
            eventoId: state.pathParameters['eventoId']!,
            leadId: state.pathParameters['leadId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/capturador/:id/exportar',
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: ExportarLeadsScreen(
            eventoId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.perfil,
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: const MiPerfilScreen(),
        ),
      ),
      GoRoute(
        path: RoutePaths.actualizaciones,
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: const ActualizacionesScreen(),
        ),
      ),
      GoRoute(
        path: RoutePaths.nuevoUsuario,
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: const NuevoUsuarioScreen(),
        ),
      ),
      GoRoute(
        path: '/usuarios/:id/editar',
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: EditarUsuarioScreen(
            usuarioId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/r/:eventoId',
        redirect: (context, state) =>
            RoutePaths.registroPublico(state.pathParameters['eventoId']!),
      ),
      GoRoute(
        path: RoutePaths.registroForms,
        builder: (context, state) {
          final eventoId = state.uri.queryParameters['id'];
          if (eventoId == null || eventoId.isEmpty) {
            return const RegistroPublicoScreen(eventoId: '');
          }
          return RegistroPublicoScreen(eventoId: eventoId);
        },
      ),
    ],
  );
});
