import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../data/models/evento.dart';
import '../../../data/models/evento_lead.dart';
import '../../../data/repositories/eventos_leads_repository.dart';
import '../providers/capturador_providers.dart';

/// Resuelve o crea una campaña de leads a partir del nombre y metadatos
/// de un evento de registro/acreditación.
///
/// La creación vía QR está permitida a `user`/`externo` por RLS; el botón
/// "Nueva campaña" de la UI sigue oculto si `!canCreateContent`.
Future<EventoLead> obtenerOCrearCampanaDesdeEvento(
  WidgetRef ref,
  Evento evento,
) async {
  final repo = ref.read(eventosLeadsRepositoryProvider);
  final isOnline = ref.read(isOnlineProvider);

  EventoLead? existente;
  if (isOnline) {
    existente = await repo.buscarPorNombre(evento.nombre);
  } else {
    final cache = ref.read(eventosLeadsListProvider).valueOrNull ?? [];
    final nombreLower = evento.nombre.trim().toLowerCase();
    existente = cache
        .where((c) => c.nombre.trim().toLowerCase() == nombreLower)
        .firstOrNull;
  }

  if (existente != null) return existente;

  if (!isOnline) {
    throw Exception(
      'Se necesita conexión para crear la campaña "${evento.nombre}".',
    );
  }

  final creada = await repo.crear(
    EventoLead(
      id: '',
      nombre: evento.nombre.trim(),
      fecha: evento.fecha,
      pais: evento.pais,
      tematica: evento.tematica,
      certificacionCapacitacion: evento.certificacionCapacitacion,
    ),
  );
  ref.invalidate(eventosLeadsListProvider);
  return creada;
}
