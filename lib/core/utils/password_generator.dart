import 'dart:math';

/// Genera una contraseña alfanumérica segura para invitaciones.
String generarContrasenaInvitacion({int length = 14}) {
  const chars =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
  final random = Random.secure();
  return List.generate(length, (_) => chars[random.nextInt(chars.length)])
      .join();
}
