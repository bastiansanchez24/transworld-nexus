import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/collapsing_nav.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/registrado.dart';
import '../../../data/offline/sync_queue_service.dart';
import '../../../data/repositories/registrados_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../registrados/providers/registrados_providers.dart';

class AcreditarConfirmadoScreen extends ConsumerStatefulWidget {
  const AcreditarConfirmadoScreen({super.key, required this.eventoId});

  final String eventoId;

  @override
  ConsumerState<AcreditarConfirmadoScreen> createState() =>
      _AcreditarConfirmadoScreenState();
}

class _AcreditarConfirmadoScreenState
    extends ConsumerState<AcreditarConfirmadoScreen> {
  final _busquedaController = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _acreditar(Registrado registrado) async {
    final userId = ref.read(currentPerfilProvider).valueOrNull?.id;
    final isOnline = ref.read(isOnlineProvider);

    try {
      if (isOnline && !esIdSoloLocal(registrado.id)) {
        await ref
            .read(registradosRepositoryProvider)
            .acreditar(registrado.id, acreditadoPorId: userId ?? '');
      } else {
        await ref
            .read(syncQueueServiceProvider.notifier)
            .enqueueUpdate(
              table: SupabaseTables.registrados,
              entityId: registrado.id,
              changes: {'acreditado': true},
            );
      }
      ref.invalidate(registradosPorEventoProvider(widget.eventoId));
      if (mounted) {
        showAppSnackBar(context, '${registrado.nombreCompleto} acreditado.');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'No se pudo acreditar.', isError: true);
      }
    }
  }

  Widget _buildSearchField() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.input),
        boxShadow: AppColors.shadowRest,
      ),
      child: TextField(
        controller: _busquedaController,
        onChanged: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.ink,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre o email…',
          hintStyle: const TextStyle(color: AppColors.placeholder),
          prefixIcon: const Icon(
            Symbols.search_rounded,
            color: AppColors.placeholder,
            size: 20,
          ),
          filled: true,
          fillColor: AppColors.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(
              color: AppColors.primaryLight,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final registradosAsync = ref.watch(
      registradosPorEventoProvider(widget.eventoId),
    );

    return CollapsingScrollScaffold(
      title: 'Acreditar asistente',
      topBanner: const OfflineBanner(),
      alwaysShowActions: true,
      overlayLeading: CollapsingNavButton(
        icon: Symbols.arrow_back_rounded,
        tooltip: 'Volver',
        onTap: () => context.pop(),
      ),
      pinnedContent: _buildSearchField(),
      pinnedContentHeight: 60,
      scrollResetToken: _busqueda,
      onRefresh: () async =>
          ref.invalidate(registradosPorEventoProvider(widget.eventoId)),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: registradosAsync.when(
              loading: () => _buildHeader(),
              error: (_, _) => _buildHeader(),
              data: (registrados) => _buildHeader(
                total: registrados.length,
                pendientes: registrados.where((r) => !r.acreditado).length,
              ),
            ),
          ),
        ),
        ...registradosAsync.when(
          loading: () => [const SliverFillRemaining(child: LoadingView())],
          error: (e, _) => [
            SliverFillRemaining(
              child: ErrorView(
                message: 'No se pudo cargar la lista.',
                onRetry: () => ref.invalidate(
                  registradosPorEventoProvider(widget.eventoId),
                ),
              ),
            ),
          ],
          data: (registrados) {
            final filtrados = registrados.where((r) {
              if (_busqueda.isEmpty) return true;
              return r.nombreCompleto.toLowerCase().contains(_busqueda) ||
                  r.email.toLowerCase().contains(_busqueda);
            }).toList();

            if (registrados.isEmpty) {
              return [
                const SliverFillRemaining(
                  child: EmptyStateView(
                    icon: Symbols.group_off_rounded,
                    message: 'Aún no hay asistentes registrados.',
                  ),
                ),
              ];
            }
            if (filtrados.isEmpty) {
              return [
                const SliverFillRemaining(
                  child: EmptyStateView(
                    icon: Symbols.search_off_rounded,
                    message: 'No se encontraron resultados.',
                  ),
                ),
              ];
            }

            return [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                sliver: SliverList.separated(
                  itemCount: filtrados.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.cardGap),
                  itemBuilder: (context, index) =>
                      _buildRegistradoTile(filtrados[index], index),
                ),
              ),
            ];
          },
        ),
      ],
    );
  }

  Widget _buildHeader({int? total, int? pendientes}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acreditar asistente',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 2),
        Text(
          total == null
              ? 'Acreditación manual'
              : '$pendientes pendientes · $total registrados',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildRegistradoTile(Registrado r, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.shadowRest,
      ),
      child: Row(
        children: [
          AvatarInitials(name: r.nombreCompleto, size: 42, index: index),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.nombreCompleto,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${r.email}${r.empresa != null && r.empresa!.isNotEmpty ? ' · ${r.empresa}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (r.acreditado)
            const StatusChip(
              label: 'Acreditado',
              variant: StatusChipVariant.success,
            )
          else
            Pressable(
              scale: 0.95,
              onTap: () => _acreditar(r),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.headerGradient,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppColors.shadowRest,
                ),
                child: const Text(
                  'Acreditar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
