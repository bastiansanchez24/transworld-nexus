import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Descarga APKs con progreso y cancelación vía Dio.
class ApkDownloader {
  ApkDownloader({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              // APK ~80 MB: sin receiveTimeout estricto; la cancelación
              // la controla el usuario.
              receiveTimeout: Duration.zero,
              headers: const {'User-Agent': 'Nexus-OTA'},
            ),
          );

  final Dio _dio;
  CancelToken? _cancelToken;

  /// Descarga [url] a un archivo en el cache de la app.
  ///
  /// [onProgress] recibe fracción 0.0–1.0 (o progreso indeterminado si
  /// `total` es desconocido: se reporta `-1` vía bytes recibidos internos
  /// y se mapea a progreso parcial solo cuando hay total).
  Future<File> download({
    required String url,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final target = File('${dir.path}/$fileName');
    if (await target.exists()) {
      await target.delete();
    }

    _cancelToken = CancelToken();
    try {
      await _dio.download(
        url,
        target.path,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (onProgress == null) return;
          if (total > 0) {
            onProgress((received / total).clamp(0.0, 1.0));
          } else if (received > 0) {
            // Sin Content-Length: progreso indeterminado → no spamear 1.0.
            onProgress(0.0);
          }
        },
      );
      if (!await target.exists() || await target.length() == 0) {
        throw const ApkDownloadException('El archivo descargado está vacío.');
      }
      return target;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        throw const ApkDownloadCancelled();
      }
      final msg = e.message ?? e.type.name;
      if (msg.toLowerCase().contains('space') ||
          msg.toLowerCase().contains('enospc')) {
        throw const ApkDownloadException(
          'Espacio insuficiente para descargar la actualización.',
        );
      }
      // Mensaje neutro: el mismo downloader sirve APK (Android) y ZIP (Windows).
      throw ApkDownloadException('Error al descargar la actualización: $msg');
    } finally {
      _cancelToken = null;
    }
  }

  void cancel() {
    final token = _cancelToken;
    if (token != null && !token.isCancelled) {
      token.cancel('cancelled_by_user');
    }
  }
}

/// Calcula SHA-256 del archivo en streaming (no carga todo en memoria).
Future<String> sha256FileHex(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString();
}

/// Compara el hash local con el digest esperado de GitHub.
///
/// Si [expectedHex] es `null` (Release antigua sin digest), retorna `true`
/// pero el llamador debe loguear el warning (política v1 del plan).
Future<bool> verifyApkSha256(File file, String? expectedHex) async {
  if (expectedHex == null || expectedHex.isEmpty) return true;
  final actual = await sha256FileHex(file);
  return actual.toLowerCase() == expectedHex.toLowerCase();
}

class ApkDownloadException implements Exception {
  const ApkDownloadException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApkDownloadCancelled implements Exception {
  const ApkDownloadCancelled();

  @override
  String toString() => 'Descarga cancelada.';
}
