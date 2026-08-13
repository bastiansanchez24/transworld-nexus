import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/perfil.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../usuarios/providers/usuarios_providers.dart';

/// Usuarios cuyo acceso a eventos se asigna de forma explícita.
final usuariosAsignablesAccesoProvider =
    FutureProvider.autoDispose<List<Perfil>>((ref) async {
      final todos = await ref.watch(usuariosListProvider.future);
      return todos.where((u) => u.requiresEventAssignment).toList()
        ..sort(
          (a, b) => a.nombreCompleto.toLowerCase().compareTo(
            b.nombreCompleto.toLowerCase(),
          ),
        );
    });

final usuariosAutorizadosEventoProvider = FutureProvider.autoDispose
    .family<Set<String>, String>((ref, eventoId) async {
      final ids = await ref
          .watch(authRepositoryProvider)
          .listarUsuariosAutorizadosEvento(eventoId);
      return ids.toSet();
    });
