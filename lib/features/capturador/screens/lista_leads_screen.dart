import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/lead.dart';
import '../../../data/repositories/leads_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/capturador_providers.dart';

class ListaLeadsScreen extends ConsumerWidget {
  const ListaLeadsScreen({super.key, required this.eventoId});

  final String eventoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadsAsync = ref.watch(leadsPorEventoProvider(eventoId));
    final eventoAsync = ref.watch(eventoLeadByIdProvider(eventoId));

    return AppScaffold(
      titleWidget: eventoAsync.when(
        data: (e) => Text('Leads · ${e.nombre}', overflow: TextOverflow.ellipsis),
        loading: () => const Text('Leads'),
        error: (_, _) => const Text('Leads'),
      ),
      floatingActionButton: NexusExtendedFab(
        label: 'Capturar',
        icon: Symbols.person_add_rounded,
        onPressed: () => context.push(RoutePaths.capturarLead(eventoId)),
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(leadsPorEventoProvider(eventoId)),
        child: leadsAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: 'No se pudieron cargar los leads.',
            onRetry: () => ref.invalidate(leadsPorEventoProvider(eventoId)),
          ),
          data: (leads) {
            if (leads.isEmpty) {
              return const EmptyStateView(
                icon: Icons.person_off_outlined,
                message: 'Aún no hay leads capturados en este evento.',
              );
            }
            return ListView.separated(
              padding: AppSpacing.screen,
              itemCount: leads.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.cardGap),
              itemBuilder: (context, index) {
                final lead = leads[index];
                return StaggeredListItem(
                  index: index,
                  child: _LeadTile(
                    eventoId: eventoId,
                    lead: lead,
                    index: index,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _LeadTile extends StatelessWidget {
  const _LeadTile({
    required this.eventoId,
    required this.lead,
    required this.index,
  });

  final String eventoId;
  final Lead lead;
  final int index;

  @override
  Widget build(BuildContext context) {
    final vendedor = lead.vendedorNombre;
    final pendiente = lead.pendienteDeSincronizar;

    return Pressable(
      onTap: pendiente
          ? null
          : () => context.push(RoutePaths.detalleLead(eventoId, lead.id)),
      enabled: !pendiente,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.shadowRest,
        ),
        child: Row(
          children: [
            AvatarInitials(
              name: lead.nombreCompleto,
              size: 44,
              index: index,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lead.nombreCompleto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  if (lead.empresa != null && lead.empresa!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      lead.empresa!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (vendedor != null && vendedor.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      vendedor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                  if (pendiente) ...[
                    const SizedBox(height: 6),
                    const StatusChip(
                      label: 'Pendiente de sincronizar',
                      variant: StatusChipVariant.warning,
                    ),
                  ],
                ],
              ),
            ),
            if (!pendiente)
              const Icon(
                Symbols.chevron_right_rounded,
                color: AppColors.chevronMuted,
              ),
          ],
        ),
      ),
    );
  }
}

class DetalleLeadScreen extends ConsumerWidget {
  const DetalleLeadScreen({
    super.key,
    required this.eventoId,
    required this.leadId,
  });

  final String eventoId;
  final String leadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadAsync = ref.watch(leadByIdProvider(leadId));
    final esAdmin = ref.watch(isAdminProvider);

    return AppScaffold(
      title: 'Detalle del lead',
      actions: [
        if (esAdmin)
          IconButton(
            icon: const Icon(Symbols.delete_outline_rounded),
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'Eliminar lead',
                message: '¿Eliminar este lead de forma permanente?',
                confirmLabel: 'Eliminar',
              );
              if (!ok) return;
              try {
                await ref.read(leadsRepositoryProvider).eliminar(leadId);
                ref.invalidate(leadsPorEventoProvider(eventoId));
                if (context.mounted) context.pop();
              } catch (_) {
                if (context.mounted) {
                  showAppSnackBar(
                    context,
                    'No se pudo eliminar el lead.',
                    isError: true,
                  );
                }
              }
            },
          ),
      ],
      body: leadAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'No se pudo cargar el lead.',
          onRetry: () => ref.invalidate(leadByIdProvider(leadId)),
        ),
        data: (lead) => ListView(
          padding: AppSpacing.screen,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                AvatarInitials(name: lead.nombreCompleto, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    lead.nombreCompleto,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _InfoRow(label: 'Empresa', value: lead.empresa),
            _InfoRow(label: 'Cargo', value: lead.cargo),
            _InfoRow(label: 'Teléfono', value: lead.telefono),
            _InfoRow(label: 'Email', value: lead.email),
            _InfoRow(label: 'Descripción', value: lead.descripcion),
            _InfoRow(label: 'Capturado por', value: lead.vendedorNombre),
            if (lead.fotosUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              const SectionLabel('Fotos'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final url in lead.fotosUrls)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        width: 120,
                        height: 120,
                        memCacheWidth: 360,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          width: 120,
                          height: 120,
                          color: AppColors.tintNavy,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, _, _) => Container(
                          width: 120,
                          height: 120,
                          color: AppColors.tintNavy,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final texto = (value == null || value!.trim().isEmpty) ? '—' : value!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
