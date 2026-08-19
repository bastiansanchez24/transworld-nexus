import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../data/repositories/auth_repository.dart';

/// Pantalla mostrada cuando un usuario externo ya no puede operar su evento.
class EventoFinalizadoScreen extends ConsumerWidget {
  const EventoFinalizadoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'Evento finalizado',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.event_busy_rounded,
                size: 64,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              const Text(
                'El evento ha finalizado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tu acceso temporal ya no está disponible.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              NexusExtendedFab(
                label: 'Volver al inicio de sesión',
                icon: Symbols.login_rounded,
                onPressed: () async {
                  await ref.read(authRepositoryProvider).cerrarSesion();
                  if (context.mounted) context.go(RoutePaths.login);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
