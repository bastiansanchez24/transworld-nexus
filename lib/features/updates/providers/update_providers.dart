import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../data/offline/sync_queue_service.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/github_release_repository.dart';
import '../services/apk_downloader.dart';
import '../services/apk_installer.dart';
import '../services/update_platform.dart';
import '../services/update_service.dart';
import '../services/windows_installer.dart';

final apkDownloaderProvider = Provider<ApkDownloader>((ref) {
  return ApkDownloader();
});

final apkInstallerProvider = Provider<ApkInstaller>((ref) {
  return ApkInstaller();
});

final windowsInstallerProvider = Provider<WindowsInstaller>((ref) {
  return WindowsInstaller();
});

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService(
    source: ref.watch(updateSourceProvider),
    prefs: ref.watch(sharedPreferencesProvider),
    downloader: ref.watch(apkDownloaderProvider),
    apkInstaller: ref.watch(apkInstallerProvider),
    windowsInstaller: ref.watch(windowsInstallerProvider),
  );
});

class UpdateController extends StateNotifier<UpdateState> {
  UpdateController(this._ref) : super(const UpdateState());

  final Ref _ref;
  bool _dialogVisible = false;

  bool get isDialogVisible => _dialogVisible;

  void markDialogVisible(bool visible) => _dialogVisible = visible;

  UpdateService get _service => _ref.read(updateServiceProvider);

  /// Check automático post-login (Android/Windows + online + debounce).
  Future<void> checkOnLaunch() => _checkAutomatic(onResume: false);

  /// Check al volver del segundo plano (ignora debounce de sesión/6h).
  Future<void> checkOnResume() => _checkAutomatic(onResume: true);

  Future<void> _checkAutomatic({required bool onResume}) async {
    if (!otaUpdatesSupported) return;
    // Solo con sesión: el modal de update no debe aparecer en login/splash.
    if (_ref.read(authRepositoryProvider).currentSession == null) return;
    if (!(_ref.read(isOnlineProvider))) return;
    if (state.isBusy) return;
    if (_dialogVisible) return;

    final previous = state;

    state = state.copyWith(status: UpdateStatus.checking, clearError: true);

    try {
      final outcome = await _service.checkForUpdates(onResume: onResume);
      if (!outcome.performed) {
        // Skip (debounce/backoff): restaurar estado previo sin marcar al día.
        state = previous;
        return;
      }
      final info = outcome.info;
      if (info == null) {
        state = state.copyWith(status: UpdateStatus.upToDate, clearInfo: true);
        return;
      }
      state = state.copyWith(
        status: UpdateStatus.available,
        info: info,
        clearError: true,
        clearDownloaded: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.failed,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Check manual desde Actualizaciones (siempre consulta; muestra feedback).
  Future<void> checkManual() async {
    if (!otaUpdatesSupported) {
      state = state.copyWith(
        status: UpdateStatus.failed,
        errorMessage: otaUnsupportedMessage,
      );
      return;
    }
    if (!(_ref.read(isOnlineProvider))) {
      state = state.copyWith(
        status: UpdateStatus.failed,
        errorMessage: 'Sin conexión a Internet.',
      );
      return;
    }

    state = state.copyWith(status: UpdateStatus.checking, clearError: true);

    try {
      final outcome = await _service.checkForUpdates(force: true, manual: true);
      final info = outcome.info;
      if (info == null) {
        state = state.copyWith(status: UpdateStatus.upToDate, clearInfo: true);
        return;
      }
      state = state.copyWith(
        status: UpdateStatus.available,
        info: info,
        clearError: true,
        clearDownloaded: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.failed,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> downloadAndInstall() async {
    final info = state.info;
    if (info == null) return;

    // Android: avisar antes de descargar si no puede instalar APKs.
    if (Platform.isAndroid && !await _service.hasInstallPermission()) {
      if (!mounted) return;
      state = state.copyWith(
        status: UpdateStatus.failed,
        needsInstallPermission: true,
        errorMessage: ApkInstaller.installPermissionMessage,
      );
      return;
    }

    state = state.copyWith(
      status: UpdateStatus.downloading,
      progress: 0,
      clearError: true,
      needsInstallPermission: false,
    );

    try {
      final file = await _service.downloadUpdate(
        info,
        onProgress: (p) {
          if (mounted) {
            state = state.copyWith(
              status: UpdateStatus.downloading,
              progress: p,
            );
          }
        },
      );

      if (!mounted) return;

      state = state.copyWith(status: UpdateStatus.verifying, progress: 1);
      final ok = await _service.verifyDownload(file, info);
      if (!ok) {
        state = state.copyWith(
          status: UpdateStatus.failed,
          errorMessage:
              'Descarga inválida (checksum). Vuelve a intentar la actualización.',
          clearDownloaded: true,
        );
        return;
      }

      state = state.copyWith(
        status: UpdateStatus.installing,
        downloadedFilePath: file.path,
      );

      final result = await _service.install(file, info: info);
      if (!mounted) return;

      _applyInstallResult(result, file.path);
    } on ApkDownloadCancelled {
      if (!mounted) return;
      state = state.copyWith(
        status: UpdateStatus.available,
        progress: 0,
        clearError: true,
      );
    } on ApkDownloadException catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        status: UpdateStatus.failed,
        errorMessage: e.message,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        status: UpdateStatus.failed,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Reintenta instalar un paquete ya verificado (Android: tras conceder permiso).
  Future<void> retryInstall() async {
    final path = state.downloadedFilePath;
    if (path == null) {
      await downloadAndInstall();
      return;
    }
    final file = File(path);
    if (!await file.exists()) {
      await downloadAndInstall();
      return;
    }

    state = state.copyWith(
      status: UpdateStatus.installing,
      clearError: true,
      needsInstallPermission: false,
    );

    final result = await _service.install(file, info: state.info);
    if (!mounted) return;

    _applyInstallResult(result, path);
  }

  void _applyInstallResult(UpdateInstallResult result, String filePath) {
    switch (result.outcome) {
      case UpdateInstallOutcome.launched:
        state = state.copyWith(status: UpdateStatus.installing);
        if (Platform.isWindows) {
          // El handshake confirmó que el updater ya corre fuera del Job
          // Object. Cerramos para liberar .exe/DLLs; PowerShell actualiza.
          Future.delayed(const Duration(milliseconds: 800), () => exit(0));
        }
        return;
      case UpdateInstallOutcome.permissionRequired:
        state = state.copyWith(
          status: UpdateStatus.failed,
          needsInstallPermission: true,
          errorMessage: result.message ?? ApkInstaller.installPermissionMessage,
          downloadedFilePath: filePath,
        );
        return;
      case UpdateInstallOutcome.unsupportedPlatform:
      case UpdateInstallOutcome.failed:
        state = state.copyWith(
          status: UpdateStatus.failed,
          errorMessage: result.message ?? 'No se pudo iniciar la instalación.',
          downloadedFilePath: filePath,
        );
    }
  }

  void cancelDownload() {
    _service.cancelDownload();
  }

  void dismiss() {
    if (state.info?.isForced == true) return;
    state = state.copyWith(status: UpdateStatus.dismissed);
  }

  Future<void> openInstallSettings() => _service.openInstallSettings();

  void resetToIdle() {
    state = const UpdateState();
    _dialogVisible = false;
  }
}

final updateControllerProvider =
    StateNotifierProvider<UpdateController, UpdateState>((ref) {
      return UpdateController(ref);
    });
