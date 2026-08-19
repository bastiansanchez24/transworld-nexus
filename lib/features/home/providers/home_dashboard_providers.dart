import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/evento.dart';
import '../../../data/repositories/eventos_repository.dart';
import '../../../data/repositories/registrados_repository.dart';

class HomeDashboardData {
  const HomeDashboardData({
    required this.eventos,
    required this.totalRegistrados,
    required this.totalAcreditados,
  });

  final List<Evento> eventos;
  final int totalRegistrados;
  final int totalAcreditados;

  int get totalEventos => eventos.length;

  int get eventosActivos => eventos.where((e) => e.activo).length;

  int get eventosProximos =>
      eventos.where((e) => !e.yaOcurrio && e.activo).length;

  int get eventosEsteMes {
    final hoy = DateTime.now();
    return eventos
        .where((e) => e.fecha.year == hoy.year && e.fecha.month == hoy.month)
        .length;
  }

  double get porcentajeAcreditacion =>
      totalRegistrados == 0 ? 0 : totalAcreditados / totalRegistrados;

  List<Evento> get proximosEventos {
    final lista = eventos.where((e) => !e.yaOcurrio).toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    return lista;
  }

  Evento? get proximoEvento =>
      proximosEventos.isEmpty ? null : proximosEventos.first;

  List<Evento> eventosEnMes(DateTime mes) {
    return eventos
        .where((e) => e.fecha.year == mes.year && e.fecha.month == mes.month)
        .toList();
  }

  List<Evento> eventosEnDia(DateTime dia) {
    return eventos
        .where(
          (e) =>
              e.fecha.year == dia.year &&
              e.fecha.month == dia.month &&
              e.fecha.day == dia.day,
        )
        .toList();
  }
}

final homeDashboardProvider = FutureProvider.autoDispose<HomeDashboardData>((
  ref,
) async {
  final eventos = await ref.watch(eventosRepositoryProvider).listarTodos();
  final resumen = await ref
      .watch(registradosRepositoryProvider)
      .obtenerResumenGlobal();
  return HomeDashboardData(
    eventos: eventos,
    totalRegistrados: resumen.total,
    totalAcreditados: resumen.acreditados,
  );
});
