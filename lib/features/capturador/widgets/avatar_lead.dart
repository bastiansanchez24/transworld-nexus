import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../data/models/lead.dart';
import '../../../data/offline/pending_photo_store.dart';
import '../../../data/repositories/storage_repository.dart';

/// Foto del lead recortada en círculo para la lista. Cae en
/// [AvatarInitials] cuando el lead no tiene foto, o cuando la que tiene
/// quedó en disco y ya no se puede leer.
///
/// La foto se sube recortada en cuadrado (ver `kProporcionFotoLead`), así que
/// el círculo no deforma nada.
class AvatarLead extends ConsumerWidget {
  const AvatarLead({
    super.key,
    required this.lead,
    this.size = 44,
    this.index = 0,
  });

  final Lead lead;
  final double size;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foto = lead.fotosUrls.firstOrNull;
    if (foto == null) return _iniciales();

    if (esFotoLocal(foto)) {
      // Capturada sin conexión: todavía vive en el dispositivo.
      final bytes = ref.watch(fotoPendienteBytesProvider(foto)).valueOrNull;
      if (bytes == null) return _iniciales();
      return _circulo(Image.memory(bytes, fit: BoxFit.cover));
    }

    if (foto.startsWith('leads/')) {
      return ref
          .watch(fotoLeadUrlProvider(foto))
          .when(
            data: _imagenRemota,
            loading: () => _circulo(Container(color: AppColors.tintNavy)),
            error: (_, _) => _iniciales(),
          );
    }

    return _imagenRemota(foto);
  }

  Widget _imagenRemota(String url) => _circulo(
    CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: (size * 3).round(),
      placeholder: (_, _) => Container(color: AppColors.tintNavy),
      errorWidget: (_, _, _) => _iniciales(),
    ),
  );

  Widget _iniciales() =>
      AvatarInitials(name: lead.nombreCompleto, size: size, index: index);

  Widget _circulo(Widget hijo) {
    return ClipOval(
      child: SizedBox(width: size, height: size, child: hijo),
    );
  }
}

final fotoLeadUrlProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, path) => ref.watch(storageRepositoryProvider).resolverFotoLead(path),
);
