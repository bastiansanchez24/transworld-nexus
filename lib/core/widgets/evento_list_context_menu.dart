import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_theme.dart';
import 'app_modals.dart';

/// Menú inferior al mantener presionado un evento o evento de leads.
Future<EventoListMenuAction?> showEventoListContextMenu(
  BuildContext context, {
  required String titulo,
  required bool fijado,
  required bool puedeEditar,
  required bool puedeEliminar,
}) {
  return showAppModalBottomSheet<EventoListMenuAction>(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                titulo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
          ListTile(
            leading: Icon(
              fijado ? Symbols.push_pin_rounded : Symbols.push_pin,
              color: AppColors.primary,
            ),
            title: Text(fijado ? 'Desfijar' : 'Fijar'),
            onTap: () => Navigator.pop(
              ctx,
              fijado
                  ? EventoListMenuAction.desfijar
                  : EventoListMenuAction.fijar,
            ),
          ),
          if (puedeEditar)
            ListTile(
              leading: const Icon(
                Symbols.edit_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Editar'),
              onTap: () => Navigator.pop(ctx, EventoListMenuAction.editar),
            ),
          if (puedeEliminar)
            ListTile(
              leading: const Icon(
                Symbols.delete_rounded,
                color: AppColors.danger,
              ),
              title: const Text(
                'Eliminar',
                style: TextStyle(color: AppColors.danger),
              ),
              onTap: () => Navigator.pop(ctx, EventoListMenuAction.eliminar),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

enum EventoListMenuAction { fijar, desfijar, editar, eliminar }
