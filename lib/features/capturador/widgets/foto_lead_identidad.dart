import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/pressable.dart';

enum _AccionFoto { ver, cambiar, eliminar }

/// Foto del lead dentro de la card de identidad.
///
/// Al tocarla ofrece verla en grande, cambiarla o eliminarla. Sin foto el
/// toque va directo al selector, para no cobrar un paso extra en el flujo de
/// captura, que se hace de pie y contra el tiempo.
class FotoLeadAvatar extends StatelessWidget {
  const FotoLeadAvatar({
    super.key,
    required this.onElegir,
    this.bytes,
    this.urlExistente,
    this.onQuitar,
    this.enabled = true,
    this.size = 76,
  });

  /// Foto recién elegida, todavía en memoria. Tiene prioridad sobre
  /// [urlExistente].
  final Uint8List? bytes;

  /// Foto ya guardada (URL firmada de Storage).
  final String? urlExistente;

  final VoidCallback onElegir;
  final VoidCallback? onQuitar;
  final bool enabled;
  final double size;

  bool get _tieneImagen => bytes != null || (urlExistente?.isNotEmpty ?? false);

  Future<void> _abrirOpciones(BuildContext context) async {
    if (!_tieneImagen) {
      onElegir();
      return;
    }

    final accion = await _preguntarAccion(
      context,
      puedeEliminar: onQuitar != null,
    );
    if (accion == null) return;

    switch (accion) {
      case _AccionFoto.ver:
        if (context.mounted) {
          await mostrarVisorFotoLead(
            context,
            bytes: bytes,
            urlExistente: urlExistente,
          );
        }
      case _AccionFoto.cambiar:
        onElegir();
      case _AccionFoto.eliminar:
        onQuitar?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _tieneImagen ? 'Foto del lead' : 'Agregar foto del lead',
      child: Pressable(
        key: const Key('lead_foto_avatar'),
        enabled: enabled,
        scale: 0.94,
        onTap: enabled ? () => _abrirOpciones(context) : null,
        child: SizedBox(
          width: size,
          height: size,
          child: _tieneImagen ? _circulo(_imagen()) : _vacio(),
        ),
      ),
    );
  }

  Widget _circulo(Widget hijo) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55),
          width: 2,
        ),
      ),
      child: ClipOval(child: hijo),
    );
  }

  Widget _vacio() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Symbols.add_a_photo_rounded,
        size: size * 0.34,
        color: Colors.white.withValues(alpha: 0.9),
      ),
    );
  }

  Widget _imagen() {
    final memoria = bytes;
    if (memoria != null) {
      return Image.memory(
        memoria,
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(),
      );
    }
    return AppNetworkImage(
      url: urlExistente!,
      fit: BoxFit.cover,
      memCacheWidth: (size * 3).round(),
      errorWidget: Container(
        color: AppColors.primaryLight,
        alignment: Alignment.center,
        child: const Icon(
          Symbols.broken_image_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

Future<_AccionFoto?> _preguntarAccion(
  BuildContext context, {
  required bool puedeEliminar,
}) {
  return showModalBottomSheet<_AccionFoto>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.header),
      ),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('lead_foto_ver'),
            leading: const Icon(
              Symbols.visibility_rounded,
              color: AppColors.primary,
            ),
            title: const Text('Ver foto'),
            onTap: () => Navigator.of(ctx).pop(_AccionFoto.ver),
          ),
          ListTile(
            key: const Key('lead_foto_cambiar'),
            leading: const Icon(
              Symbols.photo_camera_rounded,
              color: AppColors.primary,
            ),
            title: const Text('Cambiar Foto'),
            onTap: () => Navigator.of(ctx).pop(_AccionFoto.cambiar),
          ),
          if (puedeEliminar)
            ListTile(
              key: const Key('lead_foto_eliminar'),
              leading: const Icon(
                Symbols.delete_outline_rounded,
                color: AppColors.danger,
              ),
              title: const Text(
                'Eliminar Foto',
                style: TextStyle(color: AppColors.danger),
              ),
              onTap: () => Navigator.of(ctx).pop(_AccionFoto.eliminar),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

/// Abre la foto al centro de la pantalla, oscureciendo el resto.
Future<void> mostrarVisorFotoLead(
  BuildContext context, {
  Uint8List? bytes,
  String? urlExistente,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.88),
    builder: (ctx) => _VisorFoto(bytes: bytes, urlExistente: urlExistente),
  );
}

class _VisorFoto extends StatelessWidget {
  const _VisorFoto({this.bytes, this.urlExistente});

  final Uint8List? bytes;
  final String? urlExistente;

  @override
  Widget build(BuildContext context) {
    final memoria = bytes;
    final Widget imagen = memoria != null
        ? Image.memory(memoria, fit: BoxFit.contain)
        : AppNetworkImage(
            url: urlExistente ?? '',
            fit: BoxFit.contain,
            expandir: false,
            // Visor a pantalla completa sobre fondo negro: un esqueleto claro
            // ocuparía toda la pantalla. Aquí manda el spinner blanco.
            esqueletoAlCargar: false,
            placeholder: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: const Icon(
              Symbols.broken_image_rounded,
              color: Colors.white,
              size: 48,
            ),
          );

    return Dialog(
      key: const Key('lead_foto_visor'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Tocar el fondo oscurecido cierra el visor.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox.expand(),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: InteractiveViewer(
                maxScale: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: imagen,
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 12,
            child: Pressable(
              scale: 0.9,
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Symbols.close_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
