import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/offline_policy.dart';
import 'offline_image_store_stub.dart'
    if (dart.library.io) 'offline_image_store_io.dart'
    as plataforma;

/// Copia local de las imágenes que la app necesita ver sin red: portadas de
/// eventos y actividades, y avatares.
///
/// No se usa `cached_network_image`: en Chrome su caché de disco fallaba al
/// segundo pintado y sustituía la foto por el placeholder (ver
/// [AppNetworkImage]). Aquí el prefetch es **solo IO** —bajar y escribir un
/// archivo— y la decisión de qué pintar la toma el widget.
///
/// Las fotos de leads ya guardados quedan fuera a propósito: son muchas, no se
/// consultan en feria, y `PendingPhotoStore` ya cubre el único caso que
/// importa sin red (la foto recién capturada que aún no se ha subido).
class OfflineImageStore {
  OfflineImageStore._(this._dio);

  /// Instancia única.
  ///
  /// [AppNetworkImage] es un widget hoja del design system que se monta suelto
  /// en tests y no debe exigir un `ProviderScope` solo para preguntar si hay
  /// un archivo en disco. El provider de abajo expone esta misma instancia
  /// para el snapshot.
  static final OfflineImageStore instancia = OfflineImageStore._(Dio());

  final Dio _dio;

  /// Rutas ya resueltas. Sin esto, cada rebuild de una lista con portadas
  /// volvería a preguntarle al sistema de archivos.
  final Map<String, String?> _resueltas = {};

  /// Ruta conocida sin tocar disco. `null` si nunca se ha consultado esta URL.
  String? rutaEnMemoria(String url) => _resueltas[url];

  bool yaConsultada(String url) => _resueltas.containsKey(url);

  bool get disponible =>
      plataforma.almacenamientoDisponible && supportsOfflineCacheAqui;

  /// Nombre estable derivado de la URL. El hash evita que la ruta dependa de
  /// caracteres que el sistema de archivos no acepte.
  String _nombreDe(String url) {
    final hash = sha1.convert(utf8.encode(url)).toString();
    return '$hash.img';
  }

  /// Ruta local de [url] si ya está descargada; `null` si no.
  Future<String?> rutaLocal(String url) async {
    if (!disponible || url.isEmpty) return null;
    if (_resueltas.containsKey(url)) return _resueltas[url];
    try {
      final ruta = await plataforma.rutaDe(_nombreDe(url));
      final encontrada = await plataforma.existe(ruta) ? ruta : null;
      _resueltas[url] = encontrada;
      return encontrada;
    } catch (e) {
      developer.log('No se pudo resolver $url: $e', name: 'OfflineImageStore');
      return null;
    }
  }

  /// Descarga [url] si aún no está en disco. Idempotente y silencioso: una
  /// imagen que falla no puede tumbar el snapshot.
  Future<void> prefetch(String? url) async {
    if (!disponible || url == null || url.isEmpty) return;
    try {
      final ruta = await plataforma.rutaDe(_nombreDe(url));
      if (await plataforma.existe(ruta)) {
        _resueltas[url] = ruta;
        return;
      }
      final respuesta = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final bytes = respuesta.data;
      if (bytes == null || bytes.isEmpty) return;
      await plataforma.escribir(ruta, Uint8List.fromList(bytes));
      _resueltas[url] = ruta;
    } catch (e) {
      developer.log('No se pudo precargar $url: $e', name: 'OfflineImageStore');
    }
  }

  Future<void> vaciar() async {
    _resueltas.clear();
    await plataforma.borrarTodo();
  }
}

final offlineImageStoreProvider = Provider<OfflineImageStore>((ref) {
  return OfflineImageStore.instancia;
});
