import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_network_image.dart';

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

/// Foto de portada a sangre. Delega la red a [AppNetworkImage] para que
/// sobreviva rebuilds en web (swipe del home, reabrir un evento).
class EventoHeroFoto extends StatelessWidget {
  const EventoHeroFoto({super.key, required this.imagenUrl, this.velo = 0.40});

  final String imagenUrl;

  /// Opacidad del velo negro. `0` deja la foto a sangre (el padre pinta el suyo).
  final double velo;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AppNetworkImage(
          url: imagenUrl,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          placeholder: const EventoHeroGradiente(),
          errorWidget: const EventoHeroGradiente(),
        ),
        if (velo > 0) ColoredBox(color: Colors.black.withValues(alpha: velo)),
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
