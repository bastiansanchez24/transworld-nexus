import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

const excelMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// App de escritorio Windows (no web).
bool get esWindowsApp =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

/// Entrega un archivo de exportación.
///
/// En Windows abre el diálogo nativo "Guardar como" (descarga local).
/// En el resto de plataformas usa el sheet de compartir.
///
/// Devuelve `true` si se entregó el archivo, `false` si el usuario canceló
/// el diálogo de guardado (solo Windows).
Future<bool> entregarExportacion({
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
    if (location == null) return false;

    await XFile.fromData(
      bytes,
      name: nombreArchivo,
      mimeType: mimeType,
    ).saveTo(location.path);
    return true;
  }

  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          bytes,
          name: nombreArchivo,
          mimeType: mimeType,
        ),
      ],
      fileNameOverrides: [nombreArchivo],
    ),
  );
  return true;
}
