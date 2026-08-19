import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../registrados/providers/registrados_providers.dart';

class KpiData {
  const KpiData({
    required this.total,
    required this.acreditados,
    required this.pendientesDeSync,
    required this.porcentaje,
    required this.topEmpresas,
  });

  final int total;
  final int acreditados;
  final int pendientesDeSync;
  final double porcentaje;
  final List<MapEntry<String, int>> topEmpresas;
}

final kpiDataPorEventoProvider = FutureProvider.autoDispose
    .family<KpiData, String>((ref, eventoId) async {
      final registrados = await ref.watch(
        registradosPorEventoProvider(eventoId).future,
      );

      final total = registrados.length;
      final acreditados = registrados.where((r) => r.acreditado).length;
      final pendientesDeSync = registrados
          .where((r) => r.pendienteDeSincronizar)
          .length;
      final porcentaje = total == 0 ? 0.0 : acreditados / total;

      final porEmpresa = <String, int>{};
      for (final r in registrados) {
        final empresa = (r.empresa ?? '').trim();
        if (empresa.isEmpty) continue;
        porEmpresa[empresa] = (porEmpresa[empresa] ?? 0) + 1;
      }

      final topEmpresas = porEmpresa.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return KpiData(
        total: total,
        acreditados: acreditados,
        pendientesDeSync: pendientesDeSync,
        porcentaje: porcentaje,
        topEmpresas: topEmpresas,
      );
    });
