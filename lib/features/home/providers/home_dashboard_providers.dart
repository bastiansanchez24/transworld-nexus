import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../data/models/evento.dart';
import '../../../data/offline/offline_cache_tables.dart';
import '../../../data/offline/offline_read_cache.dart';
import '../../../data/repositories/registrados_repository.dart';
import '../../eventos/providers/eventos_providers.dart';

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

/// Conteos globales de registrados/acreditados, cacheados aparte del catálogo.
class _ResumenGlobal {
  const _ResumenGlobal({required this.total, required this.acreditados});

  final int total;
  final int acreditados;

  factory _ResumenGlobal.fromMap(Map<String, dynamic> map) {
    return _ResumenGlobal(
      total: (map['total'] as num?)?.toInt() ?? 0,
      acreditados: (map['acreditados'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toCacheMap() => {
    'total': total,
    'acreditados': acreditados,
  };
}

/// Home del interno. Reutiliza [eventosListProvider] —que ya respalda el
/// catálogo en disco— en vez de repetir la llamada, y cachea aparte el
/// resumen global. Sin esto el home mostraba error sin red aunque el catálogo
/// estuviera guardado.
final homeDashboardProvider = FutureProvider.autoDispose<HomeDashboardData>((
  ref,
) async {
  final eventos = await ref.watch(eventosListProvider.future);
  final isOnline = ref.read(isOnlineProvider);
  final repo = ref.watch(registradosRepositoryProvider);

  var resumen = const _ResumenGlobal(total: 0, acreditados: 0);
  try {
    final filas = await leerCacheFirstConRef(
      ref: ref,
      tabla: OfflineCacheTables.homeResumen,
      desdeServidor: () async {
        final remoto = await repo.obtenerResumenGlobal();
        return [
          _ResumenGlobal(total: remoto.total, acreditados: remoto.acreditados),
        ];
      },
      aFila: (r) => r.toCacheMap(),
      desdeFila: _ResumenGlobal.fromMap,
    );
    if (filas.isNotEmpty) resumen = filas.first;
  } catch (error) {
    // El catálogo ya se resolvió: mejor un home con eventos y contadores en
    // cero que una pantalla de error entera.
    if (isOnline && !isNetworkTransportError(error)) rethrow;
  }

  return HomeDashboardData(
    eventos: eventos,
    totalRegistrados: resumen.total,
    totalAcreditados: resumen.acreditados,
  );
});
