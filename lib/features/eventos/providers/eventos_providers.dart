import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/evento.dart';
import '../../../data/repositories/eventos_repository.dart';

final eventosListProvider = FutureProvider.autoDispose<List<Evento>>((ref) {
  return ref.watch(eventosRepositoryProvider).listarTodos();
});

final eventoByIdProvider =
    FutureProvider.autoDispose.family<Evento, String>((ref, id) {
  return ref.watch(eventosRepositoryProvider).obtenerPorId(id);
});
