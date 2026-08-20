import '../models/lead.dart';

/// Referencia liviana a un lead ya capturado en la campaña (lookup por email).
class LeadExistente {
  const LeadExistente({
    required this.leadId,
    this.capturadorNombre,
    this.esPropio = false,
  });

  final String leadId;
  final String? capturadorNombre;
  final bool esPropio;

  factory LeadExistente.fromRpc(Map<String, dynamic> row) {
    return LeadExistente(
      leadId: row['lead_id']?.toString() ?? '',
      capturadorNombre: row['capturador_nombre']?.toString(),
      esPropio: row['es_propio'] == true,
    );
  }

  factory LeadExistente.fromLead(Lead lead, {String? perfilId}) {
    return LeadExistente(
      leadId: lead.id,
      capturadorNombre: lead.vendedorNombre,
      esPropio: perfilId != null && lead.perfilId == perfilId,
    );
  }
}

/// Misma normalización que `cl_guardar_lead` / `cl_buscar_lead_por_email`.
String? emailLeadNormalizado(String? email) {
  final texto = email?.trim().toLowerCase();
  if (texto == null || texto.isEmpty) return null;
  return texto;
}

/// Primer lead de la campaña con ese email, en el mismo orden que el RPC.
Lead? leadPorEmailEnLista(Iterable<Lead> leads, String? email) {
  final normalizado = emailLeadNormalizado(email);
  if (normalizado == null) return null;

  final coincidencias = leads.where((lead) {
    return emailLeadNormalizado(lead.email) == normalizado;
  }).toList();
  if (coincidencias.isEmpty) return null;

  coincidencias.sort((a, b) {
    final porFecha = (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
    if (porFecha != 0) return porFecha;
    return a.id.compareTo(b.id);
  });
  return coincidencias.first;
}

LeadExistente? leadExistenteEnLista(
  Iterable<Lead> leads,
  String? email, {
  String? perfilId,
}) {
  final lead = leadPorEmailEnLista(leads, email);
  if (lead == null) return null;
  return LeadExistente.fromLead(lead, perfilId: perfilId);
}
