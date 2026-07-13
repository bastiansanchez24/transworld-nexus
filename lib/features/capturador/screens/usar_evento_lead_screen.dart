import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
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
            icon: const Icon(Icons.edit_outlined),
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
            AppMenuTile(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Capturar lead',
              subtitle: 'Registrar un nuevo cliente',
              onTap: () => context.push(RoutePaths.capturarLead(eventoId)),
            ),
            AppMenuTile(
              icon: Icons.list_alt_rounded,
              title: 'Ver leads',
              subtitle: 'Listado de clientes capturados',
              onTap: () => context.push(RoutePaths.verLeads(eventoId)),
            ),
            AppMenuTile(
              icon: Icons.file_download_outlined,
              title: 'Exportar a Excel',
              subtitle: 'Descargar leads del evento',
              onTap: () => context.push(RoutePaths.exportarLeads(eventoId)),
            ),
          ];

          return ListView.separated(
            padding: AppSpacing.screen,
            itemCount: opciones.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => opciones[index],
          );
        },
      ),
    );
  }
}
