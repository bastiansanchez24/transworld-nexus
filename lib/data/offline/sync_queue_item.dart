enum SyncOperation { insert, update }

enum SyncStatus { pending, syncing, synced, failed, conflict }

/// Datos estructurados de un conflicto terminal detectado por el servidor.
///
/// No se guarda únicamente un mensaje: la bandeja necesita distinguir un
/// duplicado propio de uno ajeno y mostrar de forma fiable quién llegó primero.
class SyncConflict {
  const SyncConflict({
    required this.code,
    required this.message,
    this.entityId,
    this.primerCapturadorNombre,
    this.esPropio = false,
  });

  final String code;
  final String message;
  final String? entityId;
  final String? primerCapturadorNombre;
  final bool esPropio;

  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    'entityId': entityId,
    'primerCapturadorNombre': primerCapturadorNombre,
    'esPropio': esPropio,
  };

  factory SyncConflict.fromJson(Map<String, dynamic> json) => SyncConflict(
    code: json['code'] as String? ?? 'unknown',
    message: json['message'] as String? ?? 'Conflicto de sincronización.',
    entityId: json['entityId'] as String?,
    primerCapturadorNombre: json['primerCapturadorNombre'] as String?,
    esPropio: json['esPropio'] == true,
  );
}

/// Señala al motor que un ítem no debe volver a intentarse automáticamente.
class TerminalSyncConflictException implements Exception {
  const TerminalSyncConflictException(this.conflict);

  final SyncConflict conflict;

  @override
  String toString() => conflict.message;
}

/// Error reintentable que además permite persistir un checkpoint del servidor.
/// Evita repetir un INSERT si, por ejemplo, la fila se creó pero falló la foto.
class RetryableSyncException implements Exception {
  const RetryableSyncException(this.message, {this.payloadPatch = const {}});

  final String message;
  final Map<String, dynamic> payloadPatch;

  @override
  String toString() => message;
}

/// Ítem de la cola de sincronización offline.
///
/// Esta es la estructura que el análisis del proyecto legado recomendaba
/// como corrección (documentacion_zips_registro_pro.md, Sección 10.3),
/// reemplazando el `{ id_temp: Date.now(), accion, tabla, payload }` que
/// además tenía el bug de vivir en DOS claves de almacenamiento distintas
/// y desconectadas entre sí en la app móvil legada (Sección 3.8/17.3).
/// Acá hay una sola cola, una sola clave de almacenamiento, y cada ítem
/// tiene estado, reintentos y último error — nada de esto existía antes.
class SyncQueueItem {
  const SyncQueueItem({
    required this.id,
    required this.operation,
    required this.table,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
    this.status = SyncStatus.pending,
    this.retries = 0,
    this.lastError,
    this.ownerId,
    this.conflict,
    this.conflictNotified = false,
  });

  /// Id estable del ítem de cola. Cuando `operation == insert`, este mismo
  /// id se usa como id local temporal de la entidad (para poder mostrarla
  /// de inmediato en la UI antes de que el servidor confirme el insert).
  final String id;
  final SyncOperation operation;
  final String table;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus status;
  final int retries;
  final String? lastError;
  final String? ownerId;
  final SyncConflict? conflict;
  final bool conflictNotified;

  SyncQueueItem copyWith({
    Map<String, dynamic>? payload,
    SyncStatus? status,
    int? retries,
    String? lastError,
    DateTime? updatedAt,
    SyncConflict? conflict,
    bool clearConflict = false,
    bool? conflictNotified,
    String? ownerId,
  }) {
    return SyncQueueItem(
      id: id,
      operation: operation,
      table: table,
      payload: payload ?? this.payload,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      status: status ?? this.status,
      retries: retries ?? this.retries,
      lastError: lastError,
      ownerId: ownerId ?? this.ownerId,
      conflict: clearConflict ? null : (conflict ?? this.conflict),
      conflictNotified: conflictNotified ?? this.conflictNotified,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'operation': operation.name,
    'table': table,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'status': status.name,
    'retries': retries,
    'lastError': lastError,
    'ownerId': ownerId,
    'conflict': conflict?.toJson(),
    'conflictNotified': conflictNotified,
  };

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'] as String,
      operation: SyncOperation.values.firstWhere(
        (o) => o.name == json['operation'],
        orElse: () => SyncOperation.insert,
      ),
      table: json['table'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      status: _restoredStatus(json['status']),
      retries: (json['retries'] as int?) ?? 0,
      lastError: json['lastError'] as String?,
      ownerId: json['ownerId'] as String?,
      conflict: json['conflict'] is Map
          ? SyncConflict.fromJson(
              Map<String, dynamic>.from(json['conflict'] as Map),
            )
          : null,
      conflictNotified: json['conflictNotified'] == true,
    );
  }

  static SyncStatus _restoredStatus(Object? raw) {
    final parsed = SyncStatus.values.firstWhere(
      (status) => status.name == raw,
      orElse: () => SyncStatus.pending,
    );
    // La app pudo cerrarse mientras el ítem estaba en tránsito. No hay ningún
    // worker vivo tras reiniciar, así que se recupera como reintentable.
    return parsed == SyncStatus.syncing ? SyncStatus.pending : parsed;
  }
}
