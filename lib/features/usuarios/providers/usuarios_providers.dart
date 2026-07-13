import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/perfil.dart';
import '../../../data/repositories/auth_repository.dart';

final usuariosListProvider = FutureProvider.autoDispose<List<Perfil>>((ref) {
  return ref.watch(authRepositoryProvider).obtenerTodosLosUsuarios();
});

final usuarioPorIdProvider =
    FutureProvider.autoDispose.family<Perfil, String>((ref, id) {
  return ref.watch(authRepositoryProvider).obtenerUsuarioPorId(id);
});
