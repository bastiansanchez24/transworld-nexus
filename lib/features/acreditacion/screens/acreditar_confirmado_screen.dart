import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/registrado.dart';
import '../../../data/offline/sync_queue_service.dart';
import '../../../data/repositories/registrados_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../registrados/providers/registrados_providers.dart';

class AcreditarConfirmadoScreen extends ConsumerStatefulWidget {
  const AcreditarConfirmadoScreen({super.key, required this.eventoId});

  final String eventoId;

  @override
  ConsumerState<AcreditarConfirmadoScreen> createState() =>
      _AcreditarConfirmadoScreenState();
}

class _AcreditarConfirmadoScreenState
    extends ConsumerState<AcreditarConfirmadoScreen> {
  final _busquedaController = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _acreditar(Registrado registrado) async {
    final userId = ref.read(currentPerfilProvider).valueOrNull?.id;
    final isOnline = ref.read(isOnlineProvider);

    try {
      if (isOnline && !registrado.pendienteDeSincronizar) {
        await ref
            .read(registradosRepositoryProvider)
            .acreditar(registrado.id, acreditadoPorId: userId ?? '');
      } else {
        await ref.read(syncQueueServiceProvider.notifier).enqueueUpdate(
              table: 'registrados',
              entityId: registrado.id,
              changes: {'acreditado': true},
            );
      }
      ref.invalidate(registradosPorEventoProvider(widget.eventoId));
      if (mounted) {
        showAppSnackBar(context, '${registrado.nombreCompleto} acreditado.');
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'No se pudo acreditar.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final registradosAsync = ref.watch(registradosPorEventoProvider(widget.eventoId));

    return AppScaffold(
      title: 'Acreditar asistente',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _busquedaController,
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre o email',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: registradosAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => const ErrorView(message: 'No se pudo cargar la lista.'),
              data: (registrados) {
                final filtrados = registrados.where((r) {
                  if (_busqueda.isEmpty) return true;
                  return r.nombreCompleto.toLowerCase().contains(_busqueda) ||
                      r.email.toLowerCase().contains(_busqueda);
                }).toList();

                if (filtrados.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.search_off_rounded,
                    message: 'No se encontraron resultados.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtrados.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final r = filtrados[index];
                    return ListTile(
                      title: Text(r.nombreCompleto),
                      subtitle: Text('${r.email}${r.empresa != null && r.empresa!.isNotEmpty ? ' · ${r.empresa}' : ''}'),
                      trailing: r.acreditado
                          ? Chip(
                              label: const Text('Acreditado'),
                              backgroundColor:
                                  AppColors.accent.withValues(alpha: 0.18),
                            )
                          : FilledButton(
                              onPressed: () => _acreditar(r),
                              child: const Text('Acreditar'),
                            ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
