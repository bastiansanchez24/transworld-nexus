import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../data/images/imagen_de_disco_stub.dart'
    if (dart.library.io) '../../data/images/imagen_de_disco_io.dart';
import '../../data/images/offline_image_store.dart';

/// Imagen remota para toda la app: perfil, leads y portadas.
///
/// No usa `CachedNetworkImage`. En Chrome su cache de disco falla al segundo
/// pintado (swipe, reabrir una pantalla, reconstruir el árbol) y el
/// `errorWidget` sustituye la foto por el placeholder. `Image.network` con
/// [gaplessPlayback] se apoya en la cache del motor y no se borra al rebuild.
///
/// En iOS y Android se resuelve **primero el archivo local** que dejó el
/// snapshot: sin eso, las portadas y los avatares desaparecían en cuanto se
/// caía la red, porque solo vivían en la memoria del proceso. En web y
/// escritorio no hay modo offline y se sigue yendo a la red.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholder,
    this.errorWidget,
    this.memCacheWidth,
    this.filterQuality = FilterQuality.medium,
    this.expandir = true,
  });

  final String url;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? memCacheWidth;
  final FilterQuality filterQuality;

  /// Llena el padre (avatares, portadas). En el visor a tamaño natural va
  /// en `false` para que [InteractiveViewer] reciba la imagen real.
  final bool expandir;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _desdeRed();

    final store = OfflineImageStore.instancia;
    if (!store.disponible) return _desdeRed();

    // Consulta ya resuelta: se decide sin frame intermedio, para que una lista
    // con portadas no parpadee en cada rebuild.
    if (store.yaConsultada(url)) {
      final ruta = store.rutaEnMemoria(url);
      return ruta == null ? _desdeRed() : _desdeDisco(ruta);
    }

    // Primera vez: se pinta la red mientras el disco responde. Si hay copia
    // local, el siguiente frame la usa.
    return FutureBuilder<String?>(
      future: store.rutaLocal(url),
      builder: (context, snapshot) {
        final ruta = snapshot.data;
        return ruta == null ? _desdeRed() : _desdeDisco(ruta);
      },
    );
  }

  Widget _desdeDisco(String ruta) {
    return imagenDeDisco(
      ruta: ruta,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      expandir: expandir,
      cacheWidth: memCacheWidth,
      alFallar: _desdeRed,
    );
  }

  Widget _desdeRed() {
    return Image.network(
      url,
      fit: fit,
      alignment: alignment,
      gaplessPlayback: true,
      filterQuality: filterQuality,
      width: expandir ? double.infinity : null,
      height: expandir ? double.infinity : null,
      cacheWidth: kIsWeb ? null : memCacheWidth,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return placeholder ?? child;
      },
      errorBuilder: (_, _, _) =>
          errorWidget ?? placeholder ?? const SizedBox.shrink(),
    );
  }
}
