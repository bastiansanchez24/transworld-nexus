/// Estados de permiso de cámara del escáner QR.
enum ScannerPermissionStatus {
  /// Aún no se consultó / solicitud.
  checking,

  /// Permiso concedido; la cámara puede iniciar.
  granted,

  /// Permiso denegado (o permanentemente); hay que ir a Ajustes.
  denied,

  /// Plataforma sin cámara usable (p. ej. restricciones web).
  unavailable,
}

/// Fase operativa del escáner (independiente del preview de cámara).
enum ScannerPhase {
  /// Listo para detectar códigos; animación de esquinas activa.
  idle,

  /// Se detectó un código; animación detenida, procesando negocio.
  processing,

  /// Mostrando feedback breve tras una acción.
  feedback,
}
