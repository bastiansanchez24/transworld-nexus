import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/perfil.dart';
import '../../../data/repositories/auth_repository.dart';

/// Emite cada cambio de sesión (login, logout, refresh de token). El router
/// (`core/router/app_router.dart`) escucha esto para decidir a qué pantalla
/// redirigir.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// Perfil de negocio (tabla `perfiles`) del usuario autenticado, con su rol
/// ya resuelto. `null` si no hay sesión activa.
final currentPerfilProvider = FutureProvider<Perfil?>((ref) async {
  // Se re-ejecuta automáticamente cada vez que cambia el estado de auth.
  ref.watch(authStateChangesProvider);
  final repo = ref.watch(authRepositoryProvider);
  if (repo.currentSession == null) return null;
  return repo.obtenerPerfilActual();
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentPerfilProvider).valueOrNull?.isAdmin ?? false;
});
