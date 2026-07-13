import 'dart:convert';

import 'package:mobile_scanner/mobile_scanner.dart';

final _uuidPattern = RegExp(
  r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
);

String _limpiar(String raw) {
  return raw
      .trim()
      .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
      .replaceAll(RegExp(r'''^["']|["']$'''), '');
}

/// Normaliza un candidato a UUID de `registrados.id`.
String? normalizarUuid(String? candidato) {
  if (candidato == null) return null;
  final limpio = _limpiar(candidato);
  if (limpio.isEmpty) return null;
  final match = _uuidPattern.firstMatch(limpio);
  return match?.group(0)?.toLowerCase();
}

/// Interpreta el texto crudo de un QR (UUID plano, JSON, URL, etc.).
String? extraerRegistradoIdDeTexto(String raw) {
  final texto = _limpiar(raw);
  if (texto.isEmpty) return null;

  final directo = normalizarUuid(texto);
  if (directo != null) return directo;

  if (texto.startsWith('{')) {
    try {
      final json = jsonDecode(texto);
      if (json is Map) {
        for (final key in ['registrado_id', 'id', 'registradoId']) {
          final id = normalizarUuid(json[key]?.toString());
          if (id != null) return id;
        }
      }
    } catch (_) {}
  }

  final uri = Uri.tryParse(texto);
  if (uri != null) {
    for (final key in ['registrado_id', 'id', 'registradoId']) {
      final id = normalizarUuid(uri.queryParameters[key]);
      if (id != null) return id;
    }
    for (final segment in uri.pathSegments) {
      final id = normalizarUuid(segment);
      if (id != null) return id;
    }
  }

  return normalizarUuid(texto);
}

/// Lee el id desde cualquier campo que exponga [mobile_scanner].
String? extraerRegistradoIdDeBarcode(Barcode barcode) {
  final candidatos = <String>{
    if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty)
      barcode.rawValue!,
    if (barcode.displayValue != null && barcode.displayValue!.isNotEmpty)
      barcode.displayValue!,
  };

  final decoded = barcode.rawDecodedBytes;
  if (decoded is DecodedBarcodeBytes) {
    final texto = utf8.decode(decoded.bytes, allowMalformed: true);
    if (texto.isNotEmpty) candidatos.add(texto);
  } else if (decoded is DecodedVisionBarcodeBytes) {
    final bytes = decoded.bytes ?? decoded.rawBytes;
    final texto = utf8.decode(bytes, allowMalformed: true);
    if (texto.isNotEmpty) candidatos.add(texto);
  }

  for (final candidato in candidatos) {
    final id = extraerRegistradoIdDeTexto(candidato);
    if (id != null) return id;
  }
  return null;
}

/// Prueba todos los códigos detectados en un frame (no solo el primero).
String? extraerRegistradoIdDeCaptura(BarcodeCapture capture) {
  for (final barcode in capture.barcodes) {
    final id = extraerRegistradoIdDeBarcode(barcode);
    if (id != null) return id;
  }
  return null;
}

/// Texto crudo leído, útil para depurar cuando el parseo falla.
String? textoLeidoDeCaptura(BarcodeCapture capture) {
  for (final barcode in capture.barcodes) {
    final raw = barcode.rawValue;
    if (raw != null && raw.isNotEmpty) return raw;
    final display = barcode.displayValue;
    if (display != null && display.isNotEmpty) return display;
  }
  return null;
}
