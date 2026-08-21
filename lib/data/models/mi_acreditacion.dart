/// Un asistente acreditado por el usuario en sesión, con el evento donde
/// ocurrió. Lo devuelve el RPC `rpe_mis_acreditados`, que es `SECURITY
/// DEFINER` a propósito: la RLS de `registrados` acota a los eventos que la
/// persona tiene asignados **hoy**, y estas acreditaciones son historia suya
/// aunque ya no opere ese evento.
class MiAcreditacion {
  const MiAcreditacion({
    required this.eventoId,
    required this.eventoNombre,
    required this.registradoId,
    required this.nombreCompleto,
    this.eventoFecha,
    this.empresa,
    this.cargo,
    this.acreditadoEn,
  });

  final String eventoId;
  final String eventoNombre;
  final DateTime? eventoFecha;
  final String registradoId;
  final String nombreCompleto;
  final String? empresa;
  final String? cargo;
  final DateTime? acreditadoEn;

  /// Empresa y cargo en una línea, sin separadores colgando.
  String get detalle =>
      [empresa, cargo].where((t) => t != null && t.isNotEmpty).join(' · ');

  factory MiAcreditacion.fromMap(Map<String, dynamic> map) {
    return MiAcreditacion(
      eventoId: map['evento_id'] as String,
      eventoNombre: map['evento_nombre'] as String? ?? 'Evento',
      eventoFecha: _fecha(map['evento_fecha']),
      registradoId: map['registrado_id'] as String,
      nombreCompleto: map['nombre_completo'] as String? ?? 'Sin nombre',
      empresa: map['empresa'] as String?,
      cargo: map['cargo'] as String?,
      acreditadoEn: _fecha(map['acreditado_en']),
    );
  }

  Map<String, dynamic> toCacheMap() => {
    'evento_id': eventoId,
    'evento_nombre': eventoNombre,
    'evento_fecha': eventoFecha?.toIso8601String(),
    'registrado_id': registradoId,
    'nombre_completo': nombreCompleto,
    'empresa': empresa,
    'cargo': cargo,
    'acreditado_en': acreditadoEn?.toIso8601String(),
  };

  static DateTime? _fecha(Object? valor) =>
      valor is String ? DateTime.tryParse(valor) : null;
}

/// Acreditaciones de un mismo evento, ya agrupadas para la lista.
class AcreditacionesPorEvento {
  const AcreditacionesPorEvento({
    required this.eventoId,
    required this.eventoNombre,
    required this.acreditados,
    this.eventoFecha,
  });

  final String eventoId;
  final String eventoNombre;
  final DateTime? eventoFecha;
  final List<MiAcreditacion> acreditados;

  /// Agrupa conservando el orden que trae el RPC (evento más reciente primero,
  /// y dentro de cada evento la acreditación más reciente arriba).
  static List<AcreditacionesPorEvento> agrupar(List<MiAcreditacion> filas) {
    final orden = <String>[];
    final porEvento = <String, List<MiAcreditacion>>{};

    for (final fila in filas) {
      final grupo = porEvento.putIfAbsent(fila.eventoId, () {
        orden.add(fila.eventoId);
        return <MiAcreditacion>[];
      });
      grupo.add(fila);
    }

    return [
      for (final eventoId in orden)
        AcreditacionesPorEvento(
          eventoId: eventoId,
          eventoNombre: porEvento[eventoId]!.first.eventoNombre,
          eventoFecha: porEvento[eventoId]!.first.eventoFecha,
          acreditados: porEvento[eventoId]!,
        ),
    ];
  }
}
