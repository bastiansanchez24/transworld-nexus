import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RoutePaths.capturarLead(eventoId)),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Capturar'),
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
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final lead = leads[index];
                return _LeadTile(eventoId: eventoId, lead: lead);
              },
            );
          },
        ),
      ),
    );
  }
}

class _LeadTile extends StatelessWidget {
  const _LeadTile({required this.eventoId, required this.lead});

  final String eventoId;
  final Lead lead;

  @override
  Widget build(BuildContext context) {
    final vendedor = lead.vendedorNombre;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: lead.pendienteDeSincronizar
            ? null
            : () => context.push(
                  RoutePaths.detalleLead(eventoId, lead.id),
                ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.nombreCompleto,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (lead.empresa != null && lead.empresa!.isNotEmpty)
                      Text(
                        lead.empresa!,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    if (vendedor != null && vendedor.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '[$vendedor]',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (lead.pendienteDeSincronizar)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Pendiente de sincronizar',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!lead.pendienteDeSincronizar)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
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
            icon: const Icon(Icons.delete_outline),
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
            _InfoRow(label: 'Nombre', value: lead.nombreCompleto),
            _InfoRow(label: 'Empresa', value: lead.empresa),
            _InfoRow(label: 'Cargo', value: lead.cargo),
            _InfoRow(label: 'Teléfono', value: lead.telefono),
            _InfoRow(label: 'Email', value: lead.email),
            _InfoRow(label: 'Descripción', value: lead.descripcion),
            _InfoRow(label: 'Capturado por', value: lead.vendedorNombre),
            if (lead.fotosUrls.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Fotos',
                style: Theme.of(context).textTheme.titleSmall,
              ),
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
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          width: 120,
                          height: 120,
                          color: AppColors.surfaceMuted,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, _, _) => Container(
                          width: 120,
                          height: 120,
                          color: AppColors.surfaceMuted,
                          child: const Icon(Icons.broken_image_outlined),
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
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(texto, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
