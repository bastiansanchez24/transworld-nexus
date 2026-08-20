import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/offline_guard.dart';
import '../../core/router/route_paths.dart';
import '../../core/widgets/app_widgets.dart';

/// Modal Sí/No para ir al hilo de un lead que ya existe.
Future<bool> confirmarAgregarComentarioLead(
  BuildContext context, {
  String title = 'Esta persona ya está capturada',
  String message = '¿Quiere agregar un comentario?',
}) {
  return confirmDialog(
    context,
    title: title,
    message: message,
    confirmLabel: 'Sí',
    cancelLabel: 'No',
  );
}

Future<void> irAComentariosLead(
  BuildContext context,
  WidgetRef ref, {
  required String eventoId,
  required String leadId,
  String? desdeEvento,
}) {
  if (!requireOnline(context, ref)) return Future.value();
  return context.push(
    RoutePaths.comentariosLead(eventoId, leadId, desdeEvento: desdeEvento),
  );
}

/// Tras un duplicado (formulario o snackbar), ofrece abrir el hilo.
Future<void> ofrecerComentarLeadDuplicado(
  BuildContext context,
  WidgetRef ref, {
  required String eventoId,
  required String leadId,
  required String mensajeDuplicado,
  String? desdeEvento,
}) async {
  showAppSnackBar(context, mensajeDuplicado, isError: true);
  final ir = await confirmarAgregarComentarioLead(
    context,
    title: mensajeDuplicado,
  );
  if (!ir || !context.mounted) return;
  await irAComentariosLead(
    context,
    ref,
    eventoId: eventoId,
    leadId: leadId,
    desdeEvento: desdeEvento,
  );
}
