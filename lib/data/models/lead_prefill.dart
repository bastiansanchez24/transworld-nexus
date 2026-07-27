import 'registrado.dart';

/// Datos iniciales para autorellenar el formulario de captura de leads.
class LeadPrefill {
  const LeadPrefill({
    this.nombreCompleto,
    this.empresa,
    this.cargo,
    this.telefono,
    this.email,
  });

  final String? nombreCompleto;
  final String? empresa;
  final String? cargo;
  final String? telefono;
  final String? email;

  factory LeadPrefill.fromRegistrado(Registrado registrado) {
    return LeadPrefill(
      nombreCompleto: _nonEmpty(registrado.nombreCompleto),
      empresa: _nonEmpty(registrado.empresa),
      cargo: _nonEmpty(registrado.cargo),
      telefono: _nonEmpty(registrado.telefono),
      email: _nonEmpty(registrado.email),
    );
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
