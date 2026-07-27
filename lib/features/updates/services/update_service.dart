import 'dart:developer' as developer;
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/version_utils.dart';
import '../../../data/models/github_release.dart';
import '../../../data/repositories/github_release_repository.dart';
import 'apk_downloader.dart';
import 'apk_installer.dart';

/// Información de una actualización disponible.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.installedVersion,
    required this.remoteVersion,
    required this.releaseName,
    required this.notes,
    required this.isForced,
    required this.apk,
    required this.tagName,
  });

  final String installedVersion;
  final String remoteVersion;
  final String releaseName;
  final String notes;
  final bool isForced;
  final GitHubReleaseAsset apk;
  final String tagName;

  String get formattedSize => formatBytes(apk.size);
}

enum UpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  verifying,
  installing,
  failed,
  dismissed,
}

class UpdateState {
  const UpdateState({
    this.status = UpdateStatus.idle,
    this.info,
    this.progress = 0,
    this.errorMessage,
    this.needsInstallPermission = false,
    this.downloadedApkPath,
  });

  final UpdateStatus status;
  final AppUpdateInfo? info;
  final double progress;
  final String? errorMessage;
  final bool needsInstallPermission;
  final String? downloadedApkPath;

  bool get isBusy =>
      status == UpdateStatus.checking ||
      status == UpdateStatus.downloading ||
      status == UpdateStatus.verifying ||
      status == UpdateStatus.installing;

  UpdateState copyWith({
    UpdateStatus? status,
    AppUpdateInfo? info,
    double? progress,
    String? errorMessage,
    bool? needsInstallPermission,
    String? downloadedApkPath,
    bool clearError = false,
    bool clearInfo = false,
    bool clearDownloaded = false,
  }) {
    return UpdateState(
      status: status ?? this.status,
      info: clearInfo ? null : (info ?? this.info),
      progress: progress ?? this.progress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      needsInstallPermission:
          needsInstallPermission ?? this.needsInstallPermission,
      downloadedApkPath: clearDownloaded
          ? null
          : (downloadedApkPath ?? this.downloadedApkPath),
    );
  }
}

const _prefsLastCheckMs = 'ota_last_check_ms';
const _prefsLastRateLimitMs = 'ota_last_rate_limit_ms';
const _checkDebounce = Duration(hours: 6);
const _rateLimitBackoff = Duration(hours: 1);

/// Orquesta check → diálogo → descarga → verify → install.
class UpdateService {
  UpdateService({
    required this._source,
    required this._prefs,
    ApkDownloader? downloader,
    ApkInstaller? installer,
  })  : _downloader = downloader ?? ApkDownloader(),
        _installer = installer ?? ApkInstaller();

  final UpdateSource _source;
  final SharedPreferences _prefs;
  final ApkDownloader _downloader;
  final ApkInstaller _installer;

  bool _checkedThisSession = false;

  /// Consulta GitHub Releases y decide si hay update.
  ///
  /// [force]: ignora debounce y flag de sesión (check manual).
  /// Retorna info si hay update; `null` si está al día o soft-fail.
  Future<AppUpdateInfo?> checkForUpdates({
    bool force = false,
    bool manual = false,
  }) async {
    if (!force) {
      if (_checkedThisSession) {
        developer.log('OTA: ya se consultó en esta sesión.', name: 'UpdateService');
        return null;
      }
      if (!_shouldCheckNow()) {
        developer.log('OTA: dentro del debounce de 6h.', name: 'UpdateService');
        return null;
      }
      if (_isInRateLimitBackoff()) {
        developer.log('OTA: backoff por rate limit.', name: 'UpdateService');
        return null;
      }
    }

    _checkedThisSession = true;

    try {
      final release = await _source.fetchLatest();
      await _prefs.setInt(
        _prefsLastCheckMs,
        DateTime.now().millisecondsSinceEpoch,
      );

      if (release.prerelease) {
        developer.log(
          'OTA: latest es prerelease; se ignora en canal stable.',
          name: 'UpdateService',
        );
        return null;
      }

      final remote = tryParseVersion(release.tagName);
      if (remote == null) {
        developer.log(
          'OTA: tag no SemVer (${release.tagName}).',
          name: 'UpdateService',
        );
        return null;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final installed = tryParseVersion(packageInfo.version);
      if (installed == null) {
        developer.log(
          'OTA: versión instalada inválida (${packageInfo.version}).',
          name: 'UpdateService',
        );
        return null;
      }

      if (!isRemoteNewer(installed, remote)) {
        developer.log(
          'OTA: al día ($installed >= $remote).',
          name: 'UpdateService',
        );
        return null;
      }

      final apk = release.resolveNexusApk();
      if (apk == null || apk.browserDownloadUrl.isEmpty) {
        developer.log('OTA: Release sin APK Nexus.', name: 'UpdateService');
        if (manual) {
          throw const GitHubReleaseException(
            'La última Release no incluye un APK de Nexus.',
          );
        }
        return null;
      }

      return AppUpdateInfo(
        installedVersion: installed.toString(),
        remoteVersion: remote.toString(),
        releaseName: release.name.isNotEmpty
            ? release.name
            : 'Nexus v${remote.toString()}',
        notes: release.notesForDisplay,
        isForced: release.isForced,
        apk: apk,
        tagName: release.tagName,
      );
    } on GitHubReleaseException catch (e) {
      if (e.isRateLimited) {
        await _prefs.setInt(
          _prefsLastRateLimitMs,
          DateTime.now().millisecondsSinceEpoch,
        );
      }
      developer.log('OTA check falló: $e', name: 'UpdateService');
      if (manual) rethrow;
      return null;
    } catch (e, st) {
      developer.log(
        'OTA check inesperado: $e',
        name: 'UpdateService',
        stackTrace: st,
      );
      if (manual) rethrow;
      return null;
    }
  }

  Future<File> downloadUpdate(
    AppUpdateInfo info, {
    void Function(double progress)? onProgress,
  }) {
    return _downloader.download(
      url: info.apk.browserDownloadUrl,
      fileName: info.apk.name,
      onProgress: onProgress,
    );
  }

  void cancelDownload() => _downloader.cancel();

  Future<bool> verifyDownload(File file, AppUpdateInfo info) async {
    final expected = info.apk.sha256Hex;
    if (expected == null) {
      developer.log(
        'OTA: Release sin digest SHA-256; se permite instalar (política v1).',
        name: 'UpdateService',
      );
      return true;
    }
    final ok = await verifyApkSha256(file, expected);
    if (!ok) {
      try {
        await file.delete();
      } catch (_) {}
    }
    return ok;
  }

  Future<ApkInstallResult> install(File file) => _installer.install(file);

  Future<bool> openInstallSettings() => _installer.openInstallSettings();

  bool _shouldCheckNow() {
    final last = _prefs.getInt(_prefsLastCheckMs);
    if (last == null) return true;
    final elapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(last),
    );
    return elapsed >= _checkDebounce;
  }

  bool _isInRateLimitBackoff() {
    final last = _prefs.getInt(_prefsLastRateLimitMs);
    if (last == null) return false;
    final elapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(last),
    );
    return elapsed < _rateLimitBackoff;
  }

  /// Expone comparación pura para tests.
  static bool wouldUpdate({
    required Version installed,
    required Version remote,
  }) =>
      isRemoteNewer(installed, remote);
}
