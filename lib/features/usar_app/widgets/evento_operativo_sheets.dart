import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';

/// Bottom sheets compartidos entre el menú operativo interno y externo.
class EventoOperativoSheets {
  EventoOperativoSheets._();

  static Future<void> mostrarOpcionesRegistrarAsistente(
    BuildContext context,
    String eventoId,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.header),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Registrar Asistente',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Symbols.person_add_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Registrar manualmente'),
              onTap: () {
                Navigator.pop(ctx);
                context.push(RoutePaths.registrar(eventoId));
              },
            ),
            ListTile(
              leading: const Icon(
                Symbols.link_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Autoregistro por cliente'),
              subtitle: const Text('Compartir enlace público / cargar Excel'),
              onTap: () {
                Navigator.pop(ctx);
                context.push(RoutePaths.registroPorCliente(eventoId));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
