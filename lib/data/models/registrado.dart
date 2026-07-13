enum OrigenRegistro {
  app,
  excel,
  publico;

  static OrigenRegistro fromString(String? raw) {
    return OrigenRegistro.values.firstWhere(
      (o) => o.name == raw,
      orElse: () => OrigenRegistro.app,
    );
  }
}

class Registrado {
  const Registrado({
    required this.id,
    required this.eventoId,
    required this.nombreCompleto,
    required this.email,
    this.acreditado = false,
    this.rut,
    this.patente,
    this.empresa,
    this.cargo,
    this.telefono,
    this.origen = OrigenRegistro.app,
    this.ingresadoPor,
    this.emailConfirmacionEnviado = false,
    this.createdAt,
    this.pendienteDeSincronizar = false,
  });

  final String id;
  final String eventoId;
  final String nombreCompleto;
  final String email;
  final bool acreditado;
  final String? rut;
  final String? patente;
  final String? empresa;
  final String? cargo;
  final String? telefono;

  /// Origen lógico del registro (app / excel / formulario público).
  /// Solo se persiste si la columna `origen` existe en `public.registrados`.
  final OrigenRegistro origen;
  final String? ingresadoPor;
  final bool emailConfirmacionEnviado;
  final DateTime? createdAt;

  /// true cuando esta fila todavía vive solo en la cola offline local y aún
  /// no fue confirmada por el servidor (ver data/offline/sync_queue_service.dart).
  final bool pendienteDeSincronizar;

  factory Registrado.fromMap(Map<String, dynamic> map) {
    return Registrado(
      id: map['id'] as String,
      eventoId: map['evento_id'] as String,
      nombreCompleto: map['nombre_completo'] as String,
      email: map['email'] as String,
      acreditado: (map['acreditado'] as bool?) ?? false,
      rut: map['rut'] as String?,
      patente: map['patente'] as String?,
      empresa: map['empresa'] as String?,
      cargo: map['cargo'] as String?,
      telefono: map['telefono'] as String?,
      origen: OrigenRegistro.fromString(map['origen'] as String?),
      ingresadoPor: map['ingresado_por'] as String?,
      emailConfirmacionEnviado:
          (map['email_confirmacion_enviado'] as bool?) ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'evento_id': eventoId,
      'nombre_completo': nombreCompleto,
      'email': email,
      'acreditado': acreditado,
      'rut': rut,
      'patente': patente,
      'empresa': empresa,
      'cargo': cargo,
      'telefono': telefono,
      'ingresado_por': ingresadoPor,
    };
  }

  Registrado copyWith({
    bool? acreditado,
    String? nombreCompleto,
    String? empresa,
    String? cargo,
    String? telefono,
    String? rut,
    String? patente,
    bool? pendienteDeSincronizar,
  }) {
    return Registrado(
      id: id,
      eventoId: eventoId,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      email: email,
      acreditado: acreditado ?? this.acreditado,
      rut: rut ?? this.rut,
      patente: patente ?? this.patente,
      empresa: empresa ?? this.empresa,
      cargo: cargo ?? this.cargo,
      telefono: telefono ?? this.telefono,
      origen: origen,
      ingresadoPor: ingresadoPor,
      emailConfirmacionEnviado: emailConfirmacionEnviado,
      createdAt: createdAt,
      pendienteDeSincronizar:
          pendienteDeSincronizar ?? this.pendienteDeSincronizar,
    );
  }
}
