import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/fijados_repository.dart';
import '../../auth/providers/auth_providers.dart';

final eventosFijadosProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  ref.watch(authStateChangesProvider);
  final repo = ref.watch(fijadosRepositoryProvider);
  final fijados = await repo.listarEventosFijados();
  final perfil = await ref.watch(currentPerfilProvider.future);
  if (perfil == null || !perfil.rol.isUsuario) return fijados;

  // Una revocación no debe dejar fijados invisibles consumiendo el límite.
  // Solo se limpia tras resolver exitosamente las asignaciones; un error de
  // red no se interpreta como una revocación.
  final autorizados = await ref.watch(usuarioEventosAutorizadosProvider.future);
  final obsoletos = fijados.difference(autorizados);
  for (final eventoId in obsoletos) {
    await repo.desfijarEvento(eventoId);
  }
  return fijados.intersection(autorizados);
});

final campanasFijadasProvider = FutureProvider.autoDispose<Set<String>>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(fijadosRepositoryProvider).listarCampanasFijadas();
});
