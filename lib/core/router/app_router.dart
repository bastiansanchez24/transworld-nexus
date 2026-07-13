import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/acreditacion/screens/acreditar_confirmado_screen.dart';
import '../../features/acreditacion/screens/acreditar_qr_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/recrear_pass_screen.dart';
import '../../features/auth/screens/recuperar_password_screen.dart';
import '../../features/auth/screens/registro_usuario_screen.dart';
import '../../features/capturador/screens/crear_editar_evento_lead_screen.dart';
import '../../features/capturador/screens/crear_lead_screen.dart';
import '../../features/capturador/screens/exportar_leads_screen.dart';
import '../../features/capturador/screens/lista_leads_screen.dart';
import '../../features/capturador/screens/listar_eventos_leads_screen.dart';
import '../../features/capturador/screens/usar_evento_lead_screen.dart';
import '../../features/eventos/screens/crear_editar_evento_screen.dart';
import '../../features/eventos/screens/listar_eventos_screen.dart';
import '../../features/exportacion/screens/exportar_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/kpi/screens/kpi_screen.dart';
import '../../features/registrados/screens/editar_registrado_screen.dart';
import '../../features/registrados/screens/ver_registrados_screen.dart';
import '../../features/registro/screens/registrar_confirmado_screen.dart';
import '../../features/registro/screens/registro_por_cliente_screen.dart';
import '../../features/registro_publico/screens/registro_publico_screen.dart';
import '../../features/usar_app/screens/usar_evento_screen.dart';
import '../../features/usuarios/screens/editar_usuario_screen.dart';
import '../../features/usuarios/screens/gestionar_usuarios_screen.dart';
import 'go_router_refresh_stream.dart';
import 'route_paths.dart';
import '../widgets/main_shell_scaffold.dart';

/// Rutas que no requieren sesión iniciada.
bool _esRutaPublica(String location) {
  return location == RoutePaths.login ||
      location == RoutePaths.registro ||
      location == RoutePaths.recuperarPassword ||
      location == RoutePaths.registroForms;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authClient = Supabase.instance.client.auth;

  final refreshListenable = GoRouterRefreshStream(authClient.onAuthStateChange);
  ref.onDispose(refreshListenable.dispose);
  // El redirect también depende del perfil de negocio (cambiar_pass), que
  // llega de forma asíncrona después del login: re-evaluar al resolverse.
  ref.listen(currentPerfilProvider, (_, _) => refreshListenable.refresh());

  return GoRouter(
    initialLocation: RoutePaths.home,
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

      if (session == null && !esPublica) {
        return RoutePaths.login;
      }
      if (session != null && location == RoutePaths.login) {
        return RoutePaths.home;
      }
      // Cambio obligatorio de contraseña (perfiles.cambiar_pass): mientras
      // esté activo, la única pantalla autenticada permitida es
      // /recrear-pass (regla 6.1 de la documentación de negocio).
      final perfil = ref.read(currentPerfilProvider).valueOrNull;
      if (session != null &&
          perfil != null &&
          perfil.cambiarPass &&
          !esPublica &&
          location != RoutePaths.recrearPass) {
        return RoutePaths.recrearPass;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.registro,
        builder: (context, state) => const RegistroUsuarioScreen(),
      ),
      GoRoute(
        path: RoutePaths.recuperarPassword,
        builder: (context, state) => const RecuperarPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.recrearPass,
        builder: (context, state) => const RecrearPassScreen(),
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
                builder: (context, state) =>
                    const ListarEventosLeadsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.usuarios,
                builder: (context, state) =>
                    const GestionarUsuariosScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.crearEvento,
        builder: (context, state) => const CrearEditarEventoScreen(),
      ),
      GoRoute(
        path: '/eventos/:id/editar',
        builder: (context, state) => CrearEditarEventoScreen(
          eventoId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/eventos/:id/usar',
        builder: (context, state) => UsarEventoScreen(
          eventoId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/eventos/:id/registrar',
        builder: (context, state) => RegistrarConfirmadoScreen(
          eventoId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/eventos/:id/registro-cliente',
        builder: (context, state) => RegistroPorClienteScreen(
          eventoId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/eventos/:id/acreditar',
        builder: (context, state) => AcreditarConfirmadoScreen(
          eventoId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/eventos/:id/acreditar-qr',
        builder: (context, state) => AcreditarQrScreen(
          eventoId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/eventos/:id/registrados',
        builder: (context, state) => VerRegistradosScreen(
          eventoId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/eventos/:eventoId/registrados/:registradoId/editar',
        builder: (context, state) => EditarRegistradoScreen(
          eventoId: state.pathParameters['eventoId']!,
          registradoId: state.pathParameters['registradoId']!,
        ),
      ),
      GoRoute(
        path: '/eventos/:id/kpi',
        builder: (context, state) => KpiScreen(
          eventoId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/eventos/:id/exportar',
        builder: (context, state) => ExportarScreen(
          eventoId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: RoutePaths.crearEventoLead,
        builder: (context, state) => const CrearEditarEventoLeadScreen(),
      ),
      GoRoute(
        path: '/capturador/:id/editar',
        builder: (context, state) => CrearEditarEventoLeadScreen(
          eventoId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/capturador/:id/usar',
        builder: (context, state) => UsarEventoLeadScreen(
          eventoId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/capturador/:id/capturar',
        builder: (context, state) => CrearLeadScreen(
          eventoId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/capturador/:id/leads',
        builder: (context, state) => ListaLeadsScreen(
          eventoId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/capturador/:eventoId/leads/:leadId',
        builder: (context, state) => DetalleLeadScreen(
          eventoId: state.pathParameters['eventoId']!,
          leadId: state.pathParameters['leadId']!,
        ),
      ),
      GoRoute(
        path: '/capturador/:id/exportar',
        builder: (context, state) => ExportarLeadsScreen(
          eventoId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/usuarios/:id/editar',
        builder: (context, state) => EditarUsuarioScreen(
          usuarioId: state.pathParameters['id']!,
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
