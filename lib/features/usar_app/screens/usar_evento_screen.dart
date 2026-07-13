import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/providers/auth_providers.dart';
import '../../eventos/providers/eventos_providers.dart';

/// Menú operativo de un evento: equivalente a `usar-app.tsx` / `UsarApp.tsx`
/// del proyecto legado, pero unificado en una sola pantalla para las tres
/// plataformas.
class UsarEventoScreen extends ConsumerWidget {
  const UsarEventoScreen({super.key, required this.eventoId});

  final String eventoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventoAsync = ref.watch(eventoByIdProvider(eventoId));
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
            onPressed: () => context.push(RoutePaths.editarEvento(eventoId)),
          ),
      ],
      body: eventoAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => const ErrorView(message: 'No se pudo cargar el evento.'),
        data: (evento) {
          final opciones = [
            AppMenuTile(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Registrar asistente',
              onTap: () => context.push(RoutePaths.registrar(eventoId)),
            ),
            AppMenuTile(
              icon: Icons.link_rounded,
              title: 'Registro por cliente',
              subtitle: 'Compartir enlace público / cargar Excel',
              onTap: () => context.push(RoutePaths.registroPorCliente(eventoId)),
            ),
            AppMenuTile(
              icon: Icons.how_to_reg_rounded,
              title: 'Acreditar (manual)',
              onTap: () => context.push(RoutePaths.acreditarConfirmado(eventoId)),
            ),
            AppMenuTile(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Acreditar por QR',
              onTap: () => context.push(RoutePaths.acreditarQr(eventoId)),
            ),
            AppMenuTile(
              icon: Icons.list_alt_rounded,
              title: 'Ver registrados',
              onTap: () => context.push(RoutePaths.verRegistrados(eventoId)),
            ),
            AppMenuTile(
              icon: Icons.bar_chart_rounded,
              title: 'KPI del evento',
              onTap: () => context.push(RoutePaths.kpi(eventoId)),
            ),
            AppMenuTile(
              icon: Icons.file_download_outlined,
              title: 'Exportar a Excel',
              onTap: () => context.push(RoutePaths.exportar(eventoId)),
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
