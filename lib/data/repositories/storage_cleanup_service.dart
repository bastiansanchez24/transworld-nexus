import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/supabase_tables.dart';
import '../../core/network/connectivity_service.dart';
import '../supabase/supabase_client_provider.dart';

/// Dispara el vaciado de los objetos de Storage que se quedaron sin dueño.
///
/// El registro de la basura lo hacen triggers en la base (sección 7 de
/// `supabase/schema.sql`), que son lo único que ve también los borrados en
/// cascada. Acá solo se pide el drenaje; la Edge Function `limpiar-storage`
/// hace el borrado real con la service role.
///
/// **Nunca propaga errores**: liberar espacio es una tarea de fondo y no puede
/// tumbar el borrado que el usuario acaba de confirmar. Lo que falle hoy sigue
/// en la cola y se drena en la próxima llamada.
class StorageCleanupService {
  StorageCleanupService(this._ref);

  final Ref _ref;

  /// Evita que cinco borrados seguidos disparen cinco invocaciones en paralelo.
  Future<void>? _enVuelo;

  /// Sin red no hay nada que pedir: la cola vive en el servidor y espera.
  Future<void> drenar() {
    if (!_ref.read(isOnlineProvider)) return Future<void>.value();
    return _enVuelo ??= _drenar().whenComplete(() => _enVuelo = null);
  }

  Future<void> _drenar() async {
    try {
      final client = _ref.read(supabaseClientProvider);
      final respuesta = await client.functions.invoke(
        SupabaseFunctions.limpiarStorage,
      );
      final datos = respuesta.data;
      if (datos is Map) {
        developer.log(
          'Storage: ${datos['borrados']} borrados, '
          '${datos['pendientes']} pendientes',
          name: 'StorageCleanup',
        );
      }
    } catch (e) {
      developer.log('Drenaje de Storage pospuesto: $e', name: 'StorageCleanup');
    }
  }
}

final storageCleanupServiceProvider = Provider<StorageCleanupService>((ref) {
  return StorageCleanupService(ref);
});
