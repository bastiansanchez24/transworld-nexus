import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../models/github_release.dart';

/// Contrato abstracto de fuente de actualizaciones (extensible a canales).
abstract class UpdateSource {
  Future<GitHubRelease> fetchLatest();
}

/// Cliente de la API pública de GitHub Releases.
class GitHubReleaseRepository implements UpdateSource {
  GitHubReleaseRepository({
    Dio? dio,
    String? owner,
    String? repo,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                headers: const {
                  'Accept': 'application/vnd.github+json',
                  'X-GitHub-Api-Version': '2022-11-28',
                  'User-Agent': 'Nexus-OTA',
                },
              ),
            ),
        _owner = owner ?? Env.githubOwner,
        _repo = repo ?? Env.githubRepo;

  final Dio _dio;
  final String _owner;
  final String _repo;

  String get _latestUrl =>
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  String get _releasesUrl =>
      'https://api.github.com/repos/$_owner/$_repo/releases';

  String _tagUrl(String tag) =>
      'https://api.github.com/repos/$_owner/$_repo/releases/tags/${Uri.encodeComponent(tag)}';

  @override
  Future<GitHubRelease> fetchLatest() async {
    return _getRelease(_latestUrl, notFoundMessage: 'No hay Releases publicados en este repositorio.');
  }

  /// Lista releases publicados (más recientes primero).
  ///
  /// Por defecto excluye drafts de la API; [includePrereleases] controla
  /// si se conservan prereleases en el resultado.
  Future<List<GitHubRelease>> fetchReleases({
    int perPage = 30,
    bool includePrereleases = false,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        _releasesUrl,
        queryParameters: {
          'per_page': perPage.clamp(1, 100),
        },
      );
      final data = response.data;
      if (data == null) {
        throw const GitHubReleaseException('Respuesta vacía de GitHub.');
      }

      final releases = <GitHubRelease>[];
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          releases.add(GitHubRelease.fromJson(item));
        } else if (item is Map) {
          releases.add(
            GitHubRelease.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }

      if (includePrereleases) return releases;
      return releases.where((r) => !r.prerelease).toList();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 403 || status == 429) {
        final retryAfter = e.response?.headers.value('retry-after');
        throw GitHubReleaseException(
          'Límite de la API de GitHub alcanzado. Reintenta más tarde.',
          statusCode: status,
          retryAfterSeconds: int.tryParse(retryAfter ?? ''),
          isRateLimited: true,
        );
      }
      if (status == 404) {
        throw const GitHubReleaseException(
          'No hay Releases publicados en este repositorio.',
          statusCode: 404,
        );
      }
      throw GitHubReleaseException(
        'No se pudo consultar GitHub Releases: ${e.message ?? e.type.name}',
        statusCode: status,
      );
    }
  }

  /// Obtiene el release cuyo tag coincide con [tag].
  ///
  /// Si el primer intento falla con 404, reintenta con/sin prefijo `v`.
  Future<GitHubRelease> fetchByTag(String tag) async {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) {
      throw const GitHubReleaseException(
        'Tag de versión vacío.',
        statusCode: 404,
      );
    }

    final candidates = <String>[trimmed];
    if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
      candidates.add(trimmed.substring(1));
    } else {
      candidates.add('v$trimmed');
    }

    GitHubReleaseException? lastNotFound;
    for (final candidate in candidates) {
      try {
        return await _getRelease(
          _tagUrl(candidate),
          notFoundMessage:
              'No se encontró un Release para la versión $trimmed.',
        );
      } on GitHubReleaseException catch (e) {
        if (e.statusCode == 404) {
          lastNotFound = e;
          continue;
        }
        rethrow;
      }
    }

    throw lastNotFound ??
        GitHubReleaseException(
          'No se encontró un Release para la versión $trimmed.',
          statusCode: 404,
        );
  }

  Future<GitHubRelease> _getRelease(
    String url, {
    required String notFoundMessage,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(url);
      final data = response.data;
      if (data == null) {
        throw const GitHubReleaseException('Respuesta vacía de GitHub.');
      }
      return GitHubRelease.fromJson(data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 403 || status == 429) {
        final retryAfter = e.response?.headers.value('retry-after');
        throw GitHubReleaseException(
          'Límite de la API de GitHub alcanzado. Reintenta más tarde.',
          statusCode: status,
          retryAfterSeconds: int.tryParse(retryAfter ?? ''),
          isRateLimited: true,
        );
      }
      if (status == 404) {
        throw GitHubReleaseException(
          notFoundMessage,
          statusCode: 404,
        );
      }
      throw GitHubReleaseException(
        'No se pudo consultar GitHub Releases: ${e.message ?? e.type.name}',
        statusCode: status,
      );
    }
  }
}

class GitHubReleaseException implements Exception {
  const GitHubReleaseException(
    this.message, {
    this.statusCode,
    this.retryAfterSeconds,
    this.isRateLimited = false,
  });

  final String message;
  final int? statusCode;
  final int? retryAfterSeconds;
  final bool isRateLimited;

  @override
  String toString() => message;
}

final githubReleaseRepositoryProvider = Provider<GitHubReleaseRepository>((ref) {
  return GitHubReleaseRepository();
});

final updateSourceProvider = Provider<UpdateSource>((ref) {
  return ref.watch(githubReleaseRepositoryProvider);
});
