import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_modals.dart';

const excelMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// App de escritorio Windows (no web).
bool get esWindowsApp =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

/// Android o iOS (no web).
bool get esAppMovil =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Resultado de [entregarExportacion].
enum EntregaExportacion {
  /// El usuario canceló el diálogo o el sheet.
  cancelada,

  /// El archivo quedó guardado en el dispositivo.
  guardada,

  /// Se abrió el sheet nativo de compartir.
  compartida,
}

enum _ModoEntrega { guardar, compartir }

/// Entrega un archivo de exportación.
///
/// - Windows: diálogo nativo "Guardar como".
/// - Android / iOS: sheet para elegir guardar (SAF / Files) o compartir.
/// - Resto: sheet de compartir.
Future<EntregaExportacion> entregarExportacion({
  required BuildContext context,
  required Uint8List bytes,
  required String nombreArchivo,
  String mimeType = excelMimeType,
}) async {
  if (esWindowsApp) {
    final location = await getSaveLocation(
      suggestedName: nombreArchivo,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Excel', extensions: ['xlsx']),
      ],
    );
    if (location == null) return EntregaExportacion.cancelada;

    await XFile.fromData(
      bytes,
      name: nombreArchivo,
      mimeType: mimeType,
    ).saveTo(location.path);
    return EntregaExportacion.guardada;
  }

  if (esAppMovil) {
    if (!context.mounted) return EntregaExportacion.cancelada;
    final modo = await _elegirModoEntrega(context);
    if (modo == null) return EntregaExportacion.cancelada;

    if (modo == _ModoEntrega.guardar) {
      final path = await FileSaver.instance.saveAs(
        name: _nombreSinExtension(nombreArchivo),
        bytes: bytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      if (path == null) return EntregaExportacion.cancelada;
      return EntregaExportacion.guardada;
    }
  }

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, name: nombreArchivo, mimeType: mimeType)],
      fileNameOverrides: [nombreArchivo],
    ),
  );
  return EntregaExportacion.compartida;
}

Future<_ModoEntrega?> _elegirModoEntrega(BuildContext context) {
  return showAppModalBottomSheet<_ModoEntrega>(
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
              Symbols.download_rounded,
              color: AppColors.primary,
            ),
            title: const Text('Guardar en el dispositivo'),
            subtitle: const Text('Elige carpeta y nombre del archivo'),
            onTap: () => Navigator.of(context).pop(_ModoEntrega.guardar),
          ),
          ListTile(
            leading: const Icon(
              Symbols.share_rounded,
              color: AppColors.primary,
            ),
            title: const Text('Compartir'),
            subtitle: const Text('Enviar por WhatsApp, correo u otra app'),
            onTap: () => Navigator.of(context).pop(_ModoEntrega.compartir),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

String _nombreSinExtension(String nombre) {
  final i = nombre.lastIndexOf('.');
  if (i <= 0) return nombre;
  return nombre.substring(0, i);
}
