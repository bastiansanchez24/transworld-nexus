import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_theme.dart';
import 'app_modals.dart';
import 'nexus_components.dart';
import 'pressable.dart';

/// Modal a pantalla casi completa para recortar una imagen con proporción fija.
///
/// Devuelve los bytes JPEG recortados o `null` si el usuario cancela.
Future<Uint8List?> mostrarModalRecorteImagen(
  BuildContext context, {
  required Uint8List imagenOriginal,
  required double recorteProporcion,
  String titulo = 'Recortar imagen',
}) {
  return showAppDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ModalRecorteImagen(
      imagenOriginal: imagenOriginal,
      recorteProporcion: recorteProporcion,
      titulo: titulo,
    ),
  );
}

class _ModalRecorteImagen extends StatefulWidget {
  const _ModalRecorteImagen({
    required this.imagenOriginal,
    required this.recorteProporcion,
    required this.titulo,
  });

  final Uint8List imagenOriginal;
  final double recorteProporcion;
  final String titulo;

  @override
  State<_ModalRecorteImagen> createState() => _ModalRecorteImagenState();
}

class _ModalRecorteImagenState extends State<_ModalRecorteImagen> {
  final _cropController = CropController();
  var _recortando = false;

  void _usarRecorte() {
    if (_recortando) return;
    setState(() => _recortando = true);
    _cropController.crop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  Pressable(
                    scale: 0.92,
                    onTap: _recortando
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Symbols.close_rounded, color: AppColors.ink),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.titulo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: ColoredBox(
                    color: AppColors.ink,
                    child: Crop(
                      controller: _cropController,
                      image: widget.imagenOriginal,
                      aspectRatio: widget.recorteProporcion,
                      baseColor: AppColors.ink,
                      maskColor: Colors.black.withValues(alpha: 0.55),
                      radius: 0,
                      onCropped: (result) {
                        if (!mounted) return;
                        switch (result) {
                          case CropSuccess(:final croppedImage):
                            Navigator.of(context).pop(croppedImage);
                          case CropFailure():
                            setState(() => _recortando = false);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _recortando
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryGradientButton(
                      label: 'Usar',
                      loading: _recortando,
                      onPressed: _recortando ? null : _usarRecorte,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
