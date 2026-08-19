import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../data/models/evento.dart';
import '../../../data/models/evento_lead.dart';
import '../../../data/repositories/eventos_leads_repository.dart';
import '../providers/capturador_providers.dart';

/// Resuelve o crea la actividad de captura interna de un evento de registro.
///
/// El vínculo es por id (`evento_origen_id`), no por nombre: dos eventos
/// homónimos ya no comparten sus leads y renombrar uno no rompe la relación.
///
/// La creación vía QR está permitida a `user`/`externo` por RLS; el botón
/// "Nuevo evento" de la UI sigue oculto si `!canCreateContent`.
Future<EventoLead> obtenerOCrearEventoLeadInterno(
  WidgetRef ref,
  Evento evento,
) async {
  final repo = ref.read(eventosLeadsRepositoryProvider);
  final isOnline = ref.read(isOnlineProvider);

  EventoLead? existente;
  if (isOnline) {
    existente = await repo.buscarPorEventoOrigen(evento.id);
  } else {
    final cache = ref.read(eventosLeadsListProvider).valueOrNull ?? [];
    existente = cache.where((e) => e.eventoOrigenId == evento.id).firstOrNull;
  }

  if (existente != null) return existente;

  if (!isOnline) {
    throw Exception(
      'Se necesita conexión para crear la actividad de captura de "${evento.nombre}".',
    );
  }

  final creado = await repo.crear(
    EventoLead.internoDesdeEvento(
      eventoOrigenId: evento.id,
      nombre: evento.nombre,
      fecha: evento.fecha,
      pais: evento.pais,
      tematica: evento.tematica,
      certificacionCapacitacion: evento.certificacionCapacitacion,
      imagenUrl: evento.imagenUrl,
    ),
  );
  ref.invalidate(eventosLeadsListProvider);
  return creado;
}
