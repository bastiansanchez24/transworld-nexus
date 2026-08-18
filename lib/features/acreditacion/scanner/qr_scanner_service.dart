import 'package:mobile_scanner/mobile_scanner.dart';

import '../qr_codigo_parser.dart';

/// Resultado tipado de un frame de escaneo.
class QrScanDecode {
  const QrScanDecode({
    required this.registradoId,
    this.rawText,
  });

  /// UUID de `registrados.id`, o null si no se pudo parsear.
  final String? registradoId;

  /// Texto crudo detectado (útil para mensajes de error).
  final String? rawText;

  bool get isValid => registradoId != null;
}

/// Parseo de capturas de [mobile_scanner] → id de asistente.
///
/// No conoce UI ni reglas de negocio (acreditar / lead).
class QRScannerService {
  const QRScannerService();

  QrScanDecode decode(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) {
      return const QrScanDecode(registradoId: null);
    }
    return QrScanDecode(
      registradoId: extraerRegistradoIdDeCaptura(capture),
      rawText: textoLeidoDeCaptura(capture),
    );
  }
}
