import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Contenedor del banner operativo de un evento: degradado navy, o la foto
/// de portada si el evento la tiene.
class EventoHeroBanner extends StatelessWidget {
  const EventoHeroBanner({
    super.key,
    required this.padding,
    required this.child,
    this.imagenUrl,
  });

  final EdgeInsetsGeometry padding;
  final Widget child;
  final String? imagenUrl;

  static const borderRadius = BorderRadius.vertical(
    bottom: Radius.circular(AppRadius.header),
  );

  bool get _tieneImagen => imagenUrl != null && imagenUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_tieneImagen) {
      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.headerGradient,
          borderRadius: borderRadius,
        ),
        padding: padding,
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: [
          Positioned.fill(child: EventoHeroFoto(imagenUrl: imagenUrl!)),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Foto de portada a sangre con velo oscuro para que el texto blanco lea.
class EventoHeroFoto extends StatefulWidget {
  const EventoHeroFoto({super.key, required this.imagenUrl});

  final String imagenUrl;

  @override
  State<EventoHeroFoto> createState() => _EventoHeroFotoState();
}

class _EventoHeroFotoState extends State<EventoHeroFoto> {
  bool _imagenLista = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: widget.imagenUrl,
          fit: BoxFit.cover,
          placeholder: (_, _) => const EventoHeroGradiente(),
          errorWidget: (_, _, _) => const EventoHeroGradiente(),
          imageBuilder: (context, imageProvider) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_imagenLista) {
                setState(() => _imagenLista = true);
              }
            });
            return Image(image: imageProvider, fit: BoxFit.cover);
          },
        ),
        if (_imagenLista)
          ColoredBox(color: Colors.black.withValues(alpha: 0.40)),
      ],
    );
  }
}

class EventoHeroGradiente extends StatelessWidget {
  const EventoHeroGradiente({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: AppColors.headerGradient),
    );
  }
}
