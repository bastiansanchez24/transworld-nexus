enum SyncOperation { insert, update }

enum SyncStatus { pending, syncing, synced, failed }

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

  SyncQueueItem copyWith({
    Map<String, dynamic>? payload,
    SyncStatus? status,
    int? retries,
    String? lastError,
    DateTime? updatedAt,
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
      status: SyncStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SyncStatus.pending,
      ),
      retries: (json['retries'] as int?) ?? 0,
      lastError: json['lastError'] as String?,
    );
  }
}
