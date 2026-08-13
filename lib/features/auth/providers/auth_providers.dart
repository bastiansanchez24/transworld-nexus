import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../data/models/evento.dart';
import '../../../data/models/perfil.dart';
import '../../../data/offline/offline_read_cache.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/eventos_repository.dart';

/// Emite cada cambio de sesión (login, logout, refresh de token). El router
/// (`core/router/app_router.dart`) escucha esto para decidir a qué pantalla
/// redirigir.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// Perfil de negocio (tabla `perfiles`) del usuario autenticado, con su rol
/// ya resuelto. `null` si no hay sesión activa.
///
/// Se re-ejecuta en cada emisión de auth. Si el stream aún no tiene valor,
/// se usa `currentSession` (p. ej. sesión ya restaurada en web) para no
/// dejar el splash esperando un future que nunca completa.
final currentPerfilProvider = FutureProvider<Perfil?>((ref) async {
  final authAsync = ref.watch(authStateChangesProvider);
  final session =
      authAsync.valueOrNull?.session ??
      ref.read(authRepositoryProvider).currentSession;

  if (session == null) {
    // Primer frame antes de initialSession: esperar la primera emisión.
    if (!authAsync.hasValue && !authAsync.hasError) {
      final authState = await ref.watch(authStateChangesProvider.future);
      if (authState.session == null) return null;
      final perfil = await ref
          .read(authRepositoryProvider)
          .obtenerPerfilActual();
      if (perfil == null) {
        throw Exception('No se encontró el perfil del usuario.');
      }
      if (!perfil.canViewAllLeads) {
        await ref
            .read(offlineReadCacheProvider)
            .retenerFilasPropias('${SupabaseTables.leads}__own', perfil.id);
      }
      return perfil;
    }
    return null;
  }

  final perfil = await ref.read(authRepositoryProvider).obtenerPerfilActual();
  if (perfil == null) {
    throw Exception('No se encontró el perfil del usuario.');
  }
  if (!perfil.canViewAllLeads) {
    await ref
        .read(offlineReadCacheProvider)
        .retenerFilasPropias('${SupabaseTables.leads}__own', perfil.id);
  }
  return perfil;
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentPerfilProvider).valueOrNull?.isAdmin ?? false;
});

final canManageUsersProvider = Provider<bool>((ref) {
  return ref.watch(currentPerfilProvider).valueOrNull?.canManageUsers ?? false;
});

final canCreateContentProvider = Provider<bool>((ref) {
  return ref.watch(currentPerfilProvider).valueOrNull?.canCreateContent ??
      false;
});

final canExportDataProvider = Provider<bool>((ref) {
  return ref.watch(currentPerfilProvider).valueOrNull?.canExportData ?? false;
});

final canViewAllLeadsProvider = Provider<bool>((ref) {
  return ref.watch(currentPerfilProvider).valueOrNull?.canViewAllLeads ?? false;
});

/// IDs de eventos que el rol interno `user` puede operar. Admin y organizador
/// no usan este provider porque conservan alcance global por RLS.
final usuarioEventosAutorizadosProvider = FutureProvider<Set<String>>((
  ref,
) async {
  ref.watch(authStateChangesProvider);
  final perfil = await ref.watch(currentPerfilProvider.future);
  if (perfil == null || !perfil.rol.isUsuario) return const {};

  final ids = await ref
      .watch(authRepositoryProvider)
      .listarEventosAutorizadosUsuario(perfil.id);
  final autorizados = ids.toSet();
  await ref
      .read(offlineReadCacheProvider)
      .retenerEventos(SupabaseTables.registrados, autorizados);
  return autorizados;
});

/// `null` mientras carga; ante error queda vacío para que el router falle
/// cerrado y RLS siga siendo la autoridad final.
final usuarioEventosAutorizadosIdsProvider = Provider<Set<String>?>((ref) {
  final perfil = ref.watch(currentPerfilProvider).valueOrNull;
  if (perfil == null || !perfil.rol.isUsuario) return const {};

  final async = ref.watch(usuarioEventosAutorizadosProvider);
  if (async.isLoading && !async.hasValue) return null;
  if (async.hasError) return const {};
  return async.valueOrNull ?? const {};
});

final isExternoProvider = Provider<bool>((ref) {
  return ref.watch(currentPerfilProvider).valueOrNull?.isExterno ?? false;
});

bool eventoExternoOperable(Evento e) => e.activo && !e.yaOcurrio;

/// Override de sesión para el evento activo (tras switcher), antes de que
/// el perfil se refresque desde la DB.
final externoEventoActivoOverrideProvider = StateProvider<String?>((ref) {
  ref.watch(authStateChangesProvider);
  return null;
});

/// Eventos autorizados del externo (`usuarios_eventos`).
final externoEventosAutorizadosProvider = FutureProvider<List<Evento>>((
  ref,
) async {
  ref.watch(authStateChangesProvider);
  final perfil = await ref.watch(currentPerfilProvider.future);
  if (perfil == null || !perfil.isExterno) return const [];

  final ids = await ref
      .watch(authRepositoryProvider)
      .listarEventosAutorizadosUsuario(perfil.id);
  await ref
      .read(offlineReadCacheProvider)
      .retenerEventos(SupabaseTables.registrados, ids.toSet());
  if (ids.isEmpty) return const [];

  final eventosRepo = ref.watch(eventosRepositoryProvider);
  final eventos = <Evento>[];
  for (final id in ids) {
    try {
      eventos.add(await eventosRepo.obtenerPorId(id));
    } catch (_) {
      // Evento borrado o inaccesible: omitir.
    }
  }
  eventos.sort((a, b) => a.nombre.compareTo(b.nombre));
  return eventos;
});

/// IDs autorizados (para comprobaciones rápidas en el router).
final externoEventosAutorizadosIdsProvider = Provider<Set<String>?>((ref) {
  final perfil = ref.watch(currentPerfilProvider).valueOrNull;
  if (perfil == null || !perfil.isExterno) return const {};

  final async = ref.watch(externoEventosAutorizadosProvider);
  if (async.isLoading && !async.hasValue) return null;
  if (async.hasError) return const {};
  return async.valueOrNull?.map((e) => e.id).toSet() ?? {};
});

String? _resolverEventoActivoId({
  required Perfil perfil,
  required List<Evento>? autorizados,
  required String? overrideId,
}) {
  if (!perfil.isExterno) return null;
  final ids = autorizados?.map((e) => e.id).toSet();

  bool permitido(String? id) {
    if (id == null || id.isEmpty) return false;
    if (ids == null) return true; // aún cargando: confiar en preferido
    return ids.contains(id);
  }

  if (permitido(overrideId)) return overrideId;

  final preferido = perfil.eventoAsignadoId;
  if (permitido(preferido)) return preferido;

  if (autorizados == null || autorizados.isEmpty) {
    return preferido; // fallback mientras carga / sin junction
  }

  final operable = autorizados.where(eventoExternoOperable).toList();
  if (operable.isNotEmpty) return operable.first.id;
  return autorizados.first.id;
}

final externoEventoIdProvider = Provider<String?>((ref) {
  final perfil = ref.watch(currentPerfilProvider).valueOrNull;
  if (perfil == null || !perfil.isExterno) return null;

  final overrideId = ref.watch(externoEventoActivoOverrideProvider);
  final authAsync = ref.watch(externoEventosAutorizadosProvider);
  final autorizados = authAsync.asData?.value;

  return _resolverEventoActivoId(
    perfil: perfil,
    autorizados: autorizados,
    overrideId: overrideId,
  );
});

final externoEventoProvider = FutureProvider<Evento?>((ref) async {
  ref.watch(authStateChangesProvider);
  final eventoId = ref.watch(externoEventoIdProvider);
  if (eventoId == null || eventoId.isEmpty) return null;
  return ref.watch(eventosRepositoryProvider).obtenerPorId(eventoId);
});

/// `true` si no queda ningún evento autorizado operable.
/// `null` mientras carga. `false` si hay al menos uno operable.
final externoSinEventosOperablesProvider = Provider<bool?>((ref) {
  final perfil = ref.watch(currentPerfilProvider).valueOrNull;
  if (perfil == null || !perfil.isExterno) return false;

  final authAsync = ref.watch(externoEventosAutorizadosProvider);
  if (authAsync.isLoading && !authAsync.hasValue) return null;
  if (authAsync.hasError) return true;

  final lista = authAsync.valueOrNull ?? const <Evento>[];
  if (lista.isEmpty) {
    // Sin filas en junction: fallback al preferido del perfil.
    final preferido = perfil.eventoAsignadoId;
    if (preferido == null || preferido.isEmpty) return true;
    final eventoAsync = ref.watch(externoEventoProvider);
    if (eventoAsync.isLoading) return null;
    if (eventoAsync.hasError) return true;
    final e = eventoAsync.valueOrNull;
    if (e == null) return true;
    return !eventoExternoOperable(e);
  }

  return !lista.any(eventoExternoOperable);
});

/// Estado de bloqueo del evento externo activo.
///
/// - `null`: aún cargando (no decidir logout/redirect).
/// - `true`: sin eventos operables (o activo inválido y sin alternativas).
/// - `false`: hay al menos un evento operable (el activo o uno al que
///   el router puede redirigir).
final externoEventoBloqueadoProvider = Provider<bool?>((ref) {
  final perfil = ref.watch(currentPerfilProvider).valueOrNull;
  if (perfil == null || !perfil.isExterno) return false;

  return ref.watch(externoSinEventosOperablesProvider);
});

/// Primer evento autorizado operable (para auto-switch si el activo murió).
final externoPrimerEventoOperableIdProvider = Provider<String?>((ref) {
  final authAsync = ref.watch(externoEventosAutorizadosProvider);
  final lista = authAsync.valueOrNull;
  if (lista == null) return null;
  for (final e in lista) {
    if (eventoExternoOperable(e)) return e.id;
  }
  return null;
});

/// Cambia el evento activo del externo, persiste y refresca providers.
Future<void> cambiarEventoActivoExterno(WidgetRef ref, String eventoId) async {
  final autorizados = ref.read(externoEventosAutorizadosIdsProvider);
  if (autorizados == null) {
    throw Exception('Aún se están cargando tus eventos autorizados.');
  }
  if (autorizados.isNotEmpty) {
    if (!autorizados.contains(eventoId)) {
      throw Exception('No estás autorizado para ese evento.');
    }
  } else {
    // Legacy sin filas en usuarios_eventos: solo el preferido del perfil.
    final preferido = ref
        .read(currentPerfilProvider)
        .valueOrNull
        ?.eventoAsignadoId;
    if (preferido == null || preferido.isEmpty || preferido != eventoId) {
      throw Exception('No estás autorizado para ese evento.');
    }
  }

  ref.read(externoEventoActivoOverrideProvider.notifier).state = eventoId;
  await ref
      .read(authRepositoryProvider)
      .actualizarEventoActivoExterno(eventoId);
  ref.invalidate(currentPerfilProvider);
  ref.invalidate(externoEventosAutorizadosProvider);
}
