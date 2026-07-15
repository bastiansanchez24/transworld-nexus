import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/capturador_providers.dart';

/// Hub operativo de un evento de captura de leads.
class UsarEventoLeadScreen extends ConsumerWidget {
  const UsarEventoLeadScreen({super.key, required this.eventoId});

  final String eventoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventoAsync = ref.watch(eventoLeadByIdProvider(eventoId));
    final esAdmin = ref.watch(isAdminProvider);

    return AppScaffold(
      titleWidget: eventoAsync.when(
        data: (e) => Text(e.nombre, overflow: TextOverflow.ellipsis),
        loading: () => const Text('Cargando...'),
        error: (_, _) => const Text('Evento'),
      ),
      actions: [
        if (esAdmin)
          IconButton(
            icon: const Icon(Symbols.edit_rounded),
            onPressed: () =>
                context.push(RoutePaths.editarEventoLead(eventoId)),
          ),
      ],
      body: eventoAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) =>
            const ErrorView(message: 'No se pudo cargar el evento.'),
        data: (evento) {
          final opciones = [
            NexusActionRow(
              icon: Symbols.person_add_rounded,
              title: 'Capturar lead',
              subtitle: 'Registrar un nuevo cliente',
              onTap: () => context.push(RoutePaths.capturarLead(eventoId)),
            ),
            NexusActionRow(
              icon: Symbols.list_alt_rounded,
              title: 'Ver leads',
              subtitle: 'Listado de clientes capturados',
              onTap: () => context.push(RoutePaths.verLeads(eventoId)),
            ),
            NexusActionRow(
              icon: Symbols.download_rounded,
              title: 'Exportar a Excel',
              subtitle: 'Descargar leads del evento',
              onTap: () => context.push(RoutePaths.exportarLeads(eventoId)),
            ),
          ];

          return ListView(
            padding: AppSpacing.screen,
            children: [
              const SizedBox(height: 8),
              const SectionLabel('Acciones'),
              const SizedBox(height: 10),
              for (var i = 0; i < opciones.length; i++) ...[
                StaggeredListItem(index: i, child: opciones[i]),
                if (i < opciones.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}
