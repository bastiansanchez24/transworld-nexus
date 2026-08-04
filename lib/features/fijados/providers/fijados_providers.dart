import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/fijados_repository.dart';
import '../../auth/providers/auth_providers.dart';

final eventosFijadosProvider = FutureProvider.autoDispose<Set<String>>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(fijadosRepositoryProvider).listarEventosFijados();
});

final campanasFijadasProvider = FutureProvider.autoDispose<Set<String>>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(fijadosRepositoryProvider).listarCampanasFijadas();
});
