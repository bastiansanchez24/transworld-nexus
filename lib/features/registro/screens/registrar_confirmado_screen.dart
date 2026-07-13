import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/registrado.dart';
import '../../../data/offline/sync_queue_service.dart';
import '../../../data/repositories/registrados_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../eventos/providers/eventos_providers.dart';
import '../../registrados/providers/registrados_providers.dart';

/// Registro manual de un asistente. Funciona igual online u offline: si no
/// hay conexión, la operación se encola con
/// `SyncQueueService.enqueueInsert` (única cola, ver Sección 17.3 de la
/// auditoría) y se sincroniza sola apenas vuelve la red — a diferencia del
/// proyecto legado, donde esto último nunca ocurría en la app móvil.
class RegistrarConfirmadoScreen extends ConsumerStatefulWidget {
  const RegistrarConfirmadoScreen({super.key, required this.eventoId});

  final String eventoId;

  @override
  ConsumerState<RegistrarConfirmadoScreen> createState() =>
      _RegistrarConfirmadoScreenState();
}

class _RegistrarConfirmadoScreenState
    extends ConsumerState<RegistrarConfirmadoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _empresaController = TextEditingController();
  final _cargoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _rutController = TextEditingController();
  final _patenteController = TextEditingController();
  bool _acreditarAhora = false;
  bool _guardando = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _empresaController.dispose();
    _cargoController.dispose();
    _telefonoController.dispose();
    _rutController.dispose();
    _patenteController.dispose();
    super.dispose();
  }

  Future<void> _guardar({required bool requiereCertificacion}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final email = _emailController.text.trim().toLowerCase();
    final isOnline = ref.read(isOnlineProvider);
    final userId = ref.read(currentPerfilProvider).valueOrNull?.id;

    try {
      if (!isOnline) {
        final cola = ref.read(syncQueueServiceProvider);
        if (existeEmailPendienteODuplicado(cola, widget.eventoId, email)) {
          throw Exception('Ese correo ya está en la cola local de este evento.');
        }
      } else {
        final yaExiste = await ref
            .read(registradosRepositoryProvider)
            .existeEmailEnEvento(widget.eventoId, email);
        if (yaExiste) {
          throw Exception('Ese correo ya está registrado en este evento.');
        }
      }

      final registrado = Registrado(
        id: '',
        eventoId: widget.eventoId,
        nombreCompleto: _nombreController.text.trim(),
        email: email,
        acreditado: _acreditarAhora,
        rut: requiereCertificacion ? _rutController.text.trim() : null,
        patente: requiereCertificacion ? _patenteController.text.trim() : null,
        empresa: _empresaController.text.trim(),
        cargo: _cargoController.text.trim(),
        telefono: _telefonoController.text.trim(),
        ingresadoPor: userId,
      );

      if (isOnline) {
        await ref.read(registradosRepositoryProvider).crear(registrado);
      } else {
        await ref.read(syncQueueServiceProvider.notifier).enqueueInsert(
              table: 'registrados',
              payload: registrado.toInsertMap(),
            );
      }

      ref.invalidate(registradosPorEventoProvider(widget.eventoId));

      if (mounted) {
        showAppSnackBar(
          context,
          isOnline ? 'Registrado con éxito.' : 'Guardado en modo local. Se subirá solo.',
        );
        _formKey.currentState!.reset();
        _nombreController.clear();
        _emailController.clear();
        _empresaController.clear();
        _cargoController.clear();
        _telefonoController.clear();
        _rutController.clear();
        _patenteController.clear();
        setState(() => _acreditarAhora = false);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventoAsync = ref.watch(eventoByIdProvider(widget.eventoId));

    return AppScaffold(
      title: 'Registrar asistente',
      body: eventoAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => const ErrorView(message: 'No se pudo cargar el evento.'),
              data: (evento) {
                final requiereCertificacion = evento.certificacionCapacitacion;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nombreController,
                          decoration: const InputDecoration(labelText: 'Nombre completo'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (v) =>
                              (v == null || !v.contains('@')) ? 'Email inválido' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _empresaController,
                          decoration: const InputDecoration(labelText: 'Empresa'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _cargoController,
                          decoration: const InputDecoration(labelText: 'Cargo'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _telefonoController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
                        ),
                        if (requiereCertificacion) ...[
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _rutController,
                            decoration: const InputDecoration(labelText: 'RUT / RUC'),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _patenteController,
                            decoration: const InputDecoration(labelText: 'Patente'),
                          ),
                        ],
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Acreditar de inmediato'),
                          value: _acreditarAhora,
                          onChanged: (v) => setState(() => _acreditarAhora = v),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _guardando
                              ? null
                              : () => _guardar(requiereCertificacion: requiereCertificacion),
                          child: _guardando
                              ? const ButtonProgress()
                              : const Text('Guardar registro'),
                        ),
                      ],
                    ),
                  ),
                );
              },
      ),
    );
  }
}
