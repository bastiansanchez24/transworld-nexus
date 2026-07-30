import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/version_utils.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/require_permission.dart';
import '../../../data/models/github_release.dart';
import '../../../data/repositories/github_release_repository.dart';
import '../providers/update_providers.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

class ActualizacionesScreen extends StatelessWidget {
  const ActualizacionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RequirePermission(
      allowed: (p) => p.usesFullShell,
      deniedMessage:
          'Actualizaciones solo está disponible para usuarios internos.',
      builder: (context) => const _ActualizacionesBody(),
    );
  }
}

class _ActualizacionesBody extends ConsumerStatefulWidget {
  const _ActualizacionesBody();

  @override
  ConsumerState<_ActualizacionesBody> createState() =>
      _ActualizacionesBodyState();
}

class _ActualizacionesBodyState extends ConsumerState<_ActualizacionesBody> {
  bool _loadingVersion = true;
  bool _loadingNotes = true;
  bool _loadingHistory = true;
  String _installedVersion = '';
  String? _releaseNotes;
  String? _notesError;
  String? _historyError;
  List<GitHubRelease> _previousReleases = const [];
  String? _expandedTag;

  @override
  void initState() {
    super.initState();
    _loadCurrentReleaseInfo();
  }

  Future<void> _loadCurrentReleaseInfo() async {
    setState(() {
      _loadingVersion = true;
      _loadingNotes = true;
      _loadingHistory = true;
      _notesError = null;
      _historyError = null;
      _releaseNotes = null;
      _previousReleases = const [];
      _expandedTag = null;
    });

    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _installedVersion = info.version;
        _loadingVersion = false;
      });

      final releases = await ref
          .read(githubReleaseRepositoryProvider)
          .fetchReleases();
      if (!mounted) return;

      final installed = tryParseVersion(info.version);
      GitHubRelease? current;
      final previous = <GitHubRelease>[];

      for (final release in releases) {
        final remote = tryParseVersion(release.tagName);
        if (installed != null && remote != null) {
          if (remote == installed) {
            current ??= release;
            continue;
          }
          if (remote < installed) {
            previous.add(release);
          }
          continue;
        }

        // Sin SemVer comparable: tratar coincidencia exacta de tag como actual.
        final tag = stripVersionPrefix(release.tagName);
        final installedTag = stripVersionPrefix(info.version);
        if (tag == installedTag) {
          current ??= release;
        } else {
          previous.add(release);
        }
      }

      if (current != null) {
        final notes = current.notesForDisplay;
        setState(() {
          _releaseNotes = notes.isEmpty ? null : notes;
          _notesError =
              notes.isEmpty ? 'Este release no incluye descripción.' : null;
          _loadingNotes = false;
          _previousReleases = previous;
          _loadingHistory = false;
        });
      } else {
        // Fallback: notas del tag exacto si no apareció en la lista paginada.
        try {
          final byTag = await ref
              .read(githubReleaseRepositoryProvider)
              .fetchByTag(info.version);
          if (!mounted) return;
          final notes = byTag.notesForDisplay;
          setState(() {
            _releaseNotes = notes.isEmpty ? null : notes;
            _notesError =
                notes.isEmpty ? 'Este release no incluye descripción.' : null;
            _loadingNotes = false;
            _previousReleases = previous;
            _loadingHistory = false;
          });
        } on GitHubReleaseException catch (e) {
          if (!mounted) return;
          setState(() {
            _notesError = e.statusCode == 404
                ? 'No se encontró la descripción de esta versión en GitHub.'
                : e.message;
            _loadingNotes = false;
            _previousReleases = previous;
            _loadingHistory = false;
          });
        }
      }
    } on GitHubReleaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingVersion = false;
        _loadingNotes = false;
        _loadingHistory = false;
        _notesError = e.statusCode == 404
            ? 'No se encontró la descripción de esta versión en GitHub.'
            : e.message;
        _historyError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingVersion = false;
        _loadingNotes = false;
        _loadingHistory = false;
        _notesError =
            'No se encontró la descripción de esta versión en GitHub.';
        _historyError = 'No se pudo cargar el historial de versiones.';
      });
    }
  }

  Future<void> _buscar() async {
    final controller = ref.read(updateControllerProvider.notifier);
    await controller.checkManual();
    if (!mounted) return;

    final state = ref.read(updateControllerProvider);
    if (state.status == UpdateStatus.upToDate) {
      showAppSnackBar(context, 'Ya tienes la última versión.');
      return;
    }
    if (state.status == UpdateStatus.failed && state.info == null) {
      showAppSnackBar(
        context,
        state.errorMessage ?? 'No se pudo buscar actualizaciones.',
        isError: true,
      );
      return;
    }
    if (state.status == UpdateStatus.available ||
        state.status == UpdateStatus.failed) {
      await showAppUpdateDialog(context, ref);
    }
  }

  String _versionLabel(String tagOrVersion) {
    final stripped = stripVersionPrefix(tagOrVersion);
    return stripped.isEmpty ? tagOrVersion : 'v$stripped';
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(updateControllerProvider);
    final checking = updateState.status == UpdateStatus.checking;
    final versionLabel = _installedVersion.isEmpty
        ? '…'
        : _versionLabel(_installedVersion);

    return AppScaffold(
      title: 'Actualizaciones',
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadCurrentReleaseInfo,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
          children: [
            StaggeredListItem(
              index: 0,
              child: _CurrentVersionCard(
                loadingVersion: _loadingVersion,
                loadingNotes: _loadingNotes,
                versionLabel: versionLabel,
                releaseNotes: _releaseNotes,
                notesError: _notesError,
                checking: checking,
                onBuscar: _buscar,
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            const StaggeredListItem(
              index: 1,
              child: SectionLabel('Historial de versiones'),
            ),
            const SizedBox(height: 12),
            if (_loadingHistory)
              const StaggeredListItem(
                index: 2,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              )
            else if (_historyError != null)
              StaggeredListItem(
                index: 2,
                child: Text(
                  _historyError!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              )
            else if (_previousReleases.isEmpty)
              const StaggeredListItem(
                index: 2,
                child: Text(
                  'No hay versiones anteriores publicadas.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              )
            else
              ...List.generate(_previousReleases.length, (index) {
                final release = _previousReleases[index];
                final expanded = _expandedTag == release.tagName;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _previousReleases.length - 1 ? 0 : 10,
                  ),
                  child: StaggeredListItem(
                    index: 2 + index,
                    child: _VersionHistoryTile(
                      versionLabel: _versionLabel(release.tagName),
                      releaseName: release.name.trim().isEmpty
                          ? null
                          : release.name.trim(),
                      notes: release.notesForDisplay,
                      expanded: expanded,
                      onToggle: () {
                        setState(() {
                          _expandedTag =
                              expanded ? null : release.tagName;
                        });
                      },
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _CurrentVersionCard extends StatelessWidget {
  const _CurrentVersionCard({
    required this.loadingVersion,
    required this.loadingNotes,
    required this.versionLabel,
    required this.releaseNotes,
    required this.notesError,
    required this.checking,
    required this.onBuscar,
  });

  final bool loadingVersion;
  final bool loadingNotes;
  final String versionLabel;
  final String? releaseNotes;
  final String? notesError;
  final bool checking;
  final VoidCallback onBuscar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.shadowRest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Symbols.system_update_rounded,
                color: AppColors.primary,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Versión instalada',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loadingVersion)
            const Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Text(
              versionLabel,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          const SizedBox(height: 14),
          const Text(
            'Descripción',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          if (loadingNotes)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (releaseNotes != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                child: Text(
                  releaseNotes!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            )
          else
            Text(
              notesError ??
                  'No se encontró la descripción de esta versión en GitHub.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: checking ? null : onBuscar,
            icon: checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Symbols.search_rounded, size: 20),
            label: Text(
              checking ? 'Buscando…' : 'Buscar actualizaciones',
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionHistoryTile extends StatelessWidget {
  const _VersionHistoryTile({
    required this.versionLabel,
    required this.releaseName,
    required this.notes,
    required this.expanded,
    required this.onToggle,
  });

  final String versionLabel;
  final String? releaseName;
  final String notes;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final description = notes.isEmpty
        ? 'Este release no incluye descripción.'
        : notes;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.shadowRest,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Pressable(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.tintNavy,
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                    ),
                    child: const Icon(
                      Symbols.history_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          versionLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        if (releaseName != null &&
                            releaseName != versionLabel) ...[
                          const SizedBox(height: 2),
                          Text(
                            releaseName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: AppMotion.toggle,
                    curve: AppMotion.ease,
                    child: const Icon(
                      Symbols.expand_more_rounded,
                      color: AppColors.chevronMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.toggle,
            curve: AppMotion.ease,
            alignment: Alignment.topCenter,
            child: expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(height: 1, color: AppColors.divider),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                        child: Text(
                          description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
