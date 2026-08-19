import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/images/image_compressor.dart';
import '../theme/app_theme.dart';
import 'app_network_image.dart';
import 'app_widgets.dart';
import 'modal_recorte_imagen.dart';
import 'nexus_components.dart';
import 'pressable.dart';

/// Proporción de la foto de un lead. Se usa para las dos cosas a la vez —
/// recortar el archivo que se sube y dimensionar el recuadro— para que no
/// puedan quedar distintas.
const double kProporcionFotoLead = 1;

/// Proporción de la portada de un evento (16:9).
const double kProporcionImagenEvento = 16 / 9;

/// Ancho del recuadro 1:1 de la foto de un lead (220 × 220).
const double kAnchoSelectorFotoLead = 220;

/// Ancho del recuadro 16:9 de la imagen de un evento (320 × 180). Más grande
/// que el del lead porque es una portada, no un retrato.
///
/// Los dos quedan por debajo del ancho del formulario (hasta 720 px): el
/// recuadro se alinea a la izquierda en vez de estirarse de lado a lado.
const double kAnchoSelectorImagenEvento = 320;

/// Abre una hoja para elegir cámara o galería, muestra el modal de recorte
/// interactivo y devuelve la imagen ya recortada y comprimida a JPEG.
/// Devuelve `null` si el usuario cancela o si la imagen no se pudo leer.
///
/// Es el único camino por el que la app incorpora imágenes: así ninguna
/// pantalla puede olvidarse de comprimir antes de subir.
Future<Uint8List?> elegirImagenComprimida(
  BuildContext context, {
  bool permitirCamara = true,
  required double recorteProporcion,
  String tituloRecorte = 'Recortar imagen',
}) async {
  final fuente = permitirCamara
      ? await _preguntarFuente(context)
      : ImageSource.gallery;
  if (fuente == null) return null;

  try {
    final archivo = await ImagePicker().pickImage(
      source: fuente,
      // Acota la memoria en Android/iOS antes de decodificar. En desktop y
      // web se ignora, por eso la compresión real se hace después.
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (archivo == null) return null;

    final original = await archivo.readAsBytes();
    if (!context.mounted) return null;

    final recortada = await mostrarModalRecorteImagen(
      context,
      imagenOriginal: original,
      recorteProporcion: recorteProporcion,
      titulo: tituloRecorte,
    );
    if (recortada == null) return null;

    return await comprimirParaSubida(recortada);
  } catch (e) {
    if (context.mounted) {
      showAppSnackBar(
        context,
        'No se pudo procesar la imagen seleccionada.',
        isError: true,
      );
    }
    return null;
  }
}

Future<ImageSource?> _preguntarFuente(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.header),
      ),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            leading: const Icon(
              Symbols.photo_camera_rounded,
              color: AppColors.primary,
            ),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(
              Symbols.photo_library_rounded,
              color: AppColors.primary,
            ),
            title: const Text('Elegir de la galería'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

/// Recuadro de imagen con los tres estados que necesitan eventos y leads:
/// vacío (invita a agregar), con una imagen recién elegida todavía en
/// memoria, o con una imagen ya guardada en Storage.
class SelectorImagen extends StatelessWidget {
  const SelectorImagen({
    super.key,
    required this.onElegir,
    this.bytes,
    this.urlExistente,
    this.onQuitar,
    this.enabled = true,
    this.aspectRatio = 16 / 9,
    this.anchoMaximo,
    this.etiquetaVacio = 'Agregar imagen',
    this.pieDeFoto,
    this.circular = false,
  });

  /// Imagen elegida en esta sesión y todavía sin subir. Tiene prioridad
  /// sobre [urlExistente].
  final Uint8List? bytes;

  /// Imagen ya subida, para el modo edición.
  final String? urlExistente;

  final VoidCallback onElegir;

  /// Si es `null` no se ofrece quitar la imagen.
  final VoidCallback? onQuitar;

  final bool enabled;

  /// Proporción del recuadro: 16/9 para la portada de un evento, 1 para la
  /// foto de un lead.
  final double aspectRatio;

  /// Tope de ancho; ver [kAnchoSelectorImagen]. Sin esto el recuadro se
  /// estira hasta el ancho del formulario.
  final double? anchoMaximo;

  final String etiquetaVacio;

  /// Aviso opcional bajo la imagen (p. ej. "pendiente de subir").
  final Widget? pieDeFoto;

  /// Recorte circular (p. ej. foto de perfil de un lead).
  final bool circular;

  bool get _tieneImagen => bytes != null || (urlExistente?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    Widget contenido = AspectRatio(
      aspectRatio: aspectRatio,
      child: _tieneImagen ? _conImagen() : _vacio(),
    );

    if (pieDeFoto != null) {
      contenido = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          contenido,
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: pieDeFoto!),
        ],
      );
    }

    if (anchoMaximo == null) return contenido;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: anchoMaximo!),
        child: contenido,
      ),
    );
  }

  Widget _vacio() {
    return DashedBorderBox(
      height: null,
      circular: circular,
      onTap: enabled ? onElegir : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Symbols.add_photo_alternate_rounded,
            size: 30,
            color: AppColors.primary,
            fill: 1,
          ),
          const SizedBox(height: 8),
          Text(
            etiquetaVacio,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _conImagen() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Pressable(
          enabled: enabled,
          onTap: enabled ? onElegir : null,
          child: circular
              ? ClipOval(child: _imagen())
              : ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: _imagen(),
                ),
        ),
        if (onQuitar != null && enabled)
          Positioned(
            top: 8,
            right: 8,
            child: Pressable(
              scale: 0.9,
              onTap: onQuitar,
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Symbols.close_rounded,
                  size: 18,
                  color: AppColors.danger,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _imagen() {
    if (bytes != null) {
      return Image.memory(
        bytes!,
        fit: BoxFit.cover,
        cacheWidth: kLadoMaximoSubida,
      );
    }
    return AppNetworkImage(
      url: urlExistente!,
      fit: BoxFit.cover,
      memCacheWidth: kLadoMaximoSubida,
      placeholder: Container(
        color: AppColors.tintNavy,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: Container(
        color: AppColors.tintNavy,
        child: const Icon(
          Symbols.broken_image_rounded,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}
