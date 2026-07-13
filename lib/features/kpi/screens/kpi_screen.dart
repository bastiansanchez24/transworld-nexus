import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../eventos/providers/eventos_providers.dart';
import '../../registrados/providers/registrados_providers.dart';

class KpiScreen extends ConsumerWidget {
  const KpiScreen({super.key, required this.eventoId});

  final String eventoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registradosAsync = ref.watch(registradosPorEventoProvider(eventoId));
    final eventoAsync = ref.watch(eventoByIdProvider(eventoId));

    return AppScaffold(
      title: 'KPI del evento',
      body: registradosAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => const ErrorView(message: 'No se pudieron cargar los datos.'),
              data: (registrados) {
                final total = registrados.length;
                final acreditados = registrados.where((r) => r.acreditado).length;
                final pendientesDeSync = registrados.where((r) => r.pendienteDeSincronizar).length;
                final porcentaje = total == 0 ? 0.0 : acreditados / total;

                final porEmpresa = <String, int>{};
                for (final r in registrados) {
                  final empresa = (r.empresa ?? '').trim();
                  if (empresa.isEmpty) continue;
                  porEmpresa[empresa] = (porEmpresa[empresa] ?? 0) + 1;
                }
                final topEmpresas = porEmpresa.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    eventoAsync.maybeWhen(
                      data: (e) => Text(e.nombre, style: Theme.of(context).textTheme.titleLarge),
                      orElse: () => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _KpiCard(label: 'Registrados', valor: '$total', icon: Icons.people_outline)),
                        const SizedBox(width: 12),
                        Expanded(child: _KpiCard(label: 'Acreditados', valor: '$acreditados', icon: Icons.check_circle_outline)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _KpiCard(
                            label: '% Acreditación',
                            valor: '${(porcentaje * 100).toStringAsFixed(0)}%',
                            icon: Icons.percent_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _KpiCard(
                            label: 'Sin sincronizar',
                            valor: '$pendientesDeSync',
                            icon: Icons.sync_problem_outlined,
                            destacar: pendientesDeSync > 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: porcentaje,
                        minHeight: 10,
                        backgroundColor: AppColors.surfaceMuted,
                        color: AppColors.accent,
                      ),
                    ),
                    if (topEmpresas.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Text('Empresas con más asistentes', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...topEmpresas.take(10).map(
                            (e) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(e.key),
                              trailing: Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                    ],
                  ],
                );
              },
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.valor, required this.icon, this.destacar = false});

  final String label;
  final String valor;
  final IconData icon;
  final bool destacar;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: destacar ? AppColors.error : AppColors.primary),
            const SizedBox(height: 8),
            Text(valor, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
