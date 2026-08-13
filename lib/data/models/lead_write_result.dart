/// Resultado estable del RPC `cl_guardar_lead`.
///
/// La base de datos es quien decide si el correo pertenece a un lead nuevo o
/// a uno ya capturado. La app no intenta reproducir esa decisión: solo traduce
/// la respuesta atómica del servidor a un tipo de dominio.
enum LeadWriteOutcome { creado, actualizado, duplicado }

class LeadWriteResult {
  const LeadWriteResult({
    required this.outcome,
    required this.leadId,
    this.primerCapturadorNombre,
    this.esPropio = false,
  });

  final LeadWriteOutcome outcome;
  final String leadId;
  final String? primerCapturadorNombre;
  final bool esPropio;

  bool get guardado => outcome != LeadWriteOutcome.duplicado;
  bool get esDuplicado => outcome == LeadWriteOutcome.duplicado;

  String get mensajeDuplicado {
    if (esPropio) return 'Ya registraste este lead en esta campaña';
    final nombre = primerCapturadorNombre?.trim();
    if (nombre == null || nombre.isEmpty) {
      return 'Este lead ya fue registrado por otro usuario';
    }
    return 'Este lead ya fue registrado por $nombre';
  }

  factory LeadWriteResult.fromRpc(Object? raw) {
    final row = _firstRow(raw);
    final resultado = row['resultado']?.toString().trim().toLowerCase();
    final leadId = row['lead_id']?.toString().trim() ?? '';
    if (leadId.isEmpty) {
      throw const FormatException(
        'cl_guardar_lead no devolvió un identificador de lead.',
      );
    }

    final outcome = switch (resultado) {
      'creado' => LeadWriteOutcome.creado,
      'actualizado' => LeadWriteOutcome.actualizado,
      'duplicado' => LeadWriteOutcome.duplicado,
      _ => throw FormatException(
        'Resultado desconocido de cl_guardar_lead: $resultado',
      ),
    };

    final primerNombre = row['primer_capturador_nombre']?.toString().trim();
    return LeadWriteResult(
      outcome: outcome,
      leadId: leadId,
      primerCapturadorNombre: primerNombre == null || primerNombre.isEmpty
          ? null
          : primerNombre,
      esPropio: row['es_propio'] == true,
    );
  }

  static Map<String, dynamic> _firstRow(Object? raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    throw const FormatException('Respuesta vacía de cl_guardar_lead.');
  }
}

/// La fila quedó confirmada, pero su foto local aún debe sincronizarse.
class LeadPhotoPendingException implements Exception {
  const LeadPhotoPendingException({
    required this.result,
    required this.fotosPendientes,
    required this.cause,
  });

  final LeadWriteResult result;
  final List<String> fotosPendientes;
  final Object cause;

  @override
  String toString() =>
      'El lead se guardó, pero la foto quedó pendiente: $cause';
}
