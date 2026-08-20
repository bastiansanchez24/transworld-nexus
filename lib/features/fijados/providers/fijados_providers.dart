import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../data/offline/offline_cache_tables.dart';
import '../../../data/offline/offline_read_cache.dart';
import '../../../data/repositories/fijados_repository.dart';
import '../../auth/providers/auth_providers.dart';

/// Los fijados son un `Set<String>`; en disco se guardan como filas con una
/// sola columna para poder reusar el mismo mecanismo que el resto del
/// catálogo.
const String _columnaId = 'id';

Map<String, dynamic> _aFila(String id) => {_columnaId: id};

String _desdeFila(Map<String, dynamic> fila) => '${fila[_columnaId]}';

/// Ids de eventos fijados por el usuario, con respaldo en disco.
final eventosFijadosProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  ref.watch(authStateChangesProvider);
  final isOnline = ref.read(isOnlineProvider);
  final repo = ref.watch(fijadosRepositoryProvider);
  final perfil = await ref.watch(currentPerfilProvider.future);

  final fijados = (await leerCacheFirstConRef(
    ref: ref,
    tabla: OfflineCacheTables.eventosFijados,
    desdeServidor: () async => (await repo.listarEventosFijados()).toList(),
    aFila: _aFila,
    desdeFila: _desdeFila,
  )).toSet();

  if (perfil == null || !perfil.rol.isUsuario) return fijados;

  // Una revocación no debe dejar fijados invisibles consumiendo el límite,
  // pero un error de red tampoco puede leerse como revocación: sin
  // autorizaciones resueltas se muestran los fijados tal cual.
  final Set<String> autorizados;
  try {
    autorizados = await ref.watch(usuarioEventosAutorizadosProvider.future);
  } catch (_) {
    return fijados;
  }

  final obsoletos = fijados.difference(autorizados);
  if (isOnline) {
    for (final eventoId in obsoletos) {
      await repo.desfijarEvento(eventoId);
    }
  }
  return fijados.intersection(autorizados);
});

final campanasFijadasProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  ref.watch(authStateChangesProvider);
  final repo = ref.watch(fijadosRepositoryProvider);

  final fijadas = await leerCacheFirstConRef(
    ref: ref,
    tabla: OfflineCacheTables.campanasFijadas,
    desdeServidor: () async => (await repo.listarCampanasFijadas()).toList(),
    aFila: _aFila,
    desdeFila: _desdeFila,
  );
  return fijadas.toSet();
});
