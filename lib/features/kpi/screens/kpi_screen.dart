import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../eventos/providers/eventos_providers.dart';
import '../providers/kpi_providers.dart';

class KpiScreen extends ConsumerWidget {
  const KpiScreen({super.key, required this.eventoId});

  final String eventoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpiDataAsync = ref.watch(kpiDataPorEventoProvider(eventoId));
    final eventoAsync = ref.watch(eventoByIdProvider(eventoId));

    return AppScaffold(
      title: 'KPI del evento',
      body: kpiDataAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => const ErrorView(message: 'No se pudieron cargar los datos.'),
              data: (kpi) {
                final total = kpi.total;
                final acreditados = kpi.acreditados;
                final pendientesDeSync = kpi.pendientesDeSync;
                final porcentaje = kpi.porcentaje;
                final topEmpresas = kpi.topEmpresas;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.xl,
                    AppSpacing.screenH,
                    AppSpacing.xxxl,
                  ),
                  children: [
                    eventoAsync.maybeWhen(
                      data: (e) => Text(
                        e.nombre,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            value: '$total',
                            label: 'Registrados',
                            icon: Symbols.group_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            value: '$acreditados',
                            label: 'Acreditados',
                            icon: Symbols.check_circle_rounded,
                            tint: AppColors.successTint,
                            iconColor: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            value: '${(porcentaje * 100).toStringAsFixed(0)}%',
                            label: '% Acreditación',
                            icon: Symbols.percent_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            value: '$pendientesDeSync',
                            label: 'Sin sincronizar',
                            icon: Symbols.sync_problem_rounded,
                            tint: pendientesDeSync > 0
                                ? AppColors.dangerTint
                                : AppColors.tintNavy,
                            iconColor: pendientesDeSync > 0
                                ? AppColors.danger
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: porcentaje,
                        minHeight: 10,
                        backgroundColor: AppColors.surfaceMuted,
                        color: AppColors.success,
                      ),
                    ),
                    if (topEmpresas.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sectionGap + 6),
                      const SectionLabel('Empresas'),
                      const SizedBox(height: 10),
                      Text(
                        'Empresas con más asistentes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      ...topEmpresas.take(10).toList().asMap().entries.map(
                            (entry) {
                              final e = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                                child: StaggeredListItem(
                                  index: entry.key,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 13,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.lg),
                                      border: Border.all(color: AppColors.border),
                                      boxShadow: AppColors.shadowRest,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            e.key,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                        ),
                                        StatusChip(
                                          label: '${e.value}',
                                          variant: StatusChipVariant.neutral,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                    ],
                  ],
                );
              },
      ),
    );
  }
}
