import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/registro_asistente.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/campos_registro_asistente.dart';
import '../../../core/widgets/nexus_components.dart';
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
  PaisTelefono _pais = kPaisTelefonoChile;
  bool _acreditarAhora = false;
  bool _guardando = false;
  bool _autovalidar = false;

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

  Future<void> _guardar({
    required bool requiereCertificacion,
    required String nombreEvento,
  }) async {
    if (_guardando) return;
    _guardando = true;

    aplicarFormatosRegistroAsistente(
      nombre: _nombreController,
      email: _emailController,
      empresa: _empresaController,
      cargo: _cargoController,
      telefono: _telefonoController,
      pais: _pais,
      rut: requiereCertificacion ? _rutController : null,
      patente: requiereCertificacion ? _patenteController : null,
    );

    if (!(_formKey.currentState?.validate() ?? false)) {
      _guardando = false;
      if (mounted) setState(() => _autovalidar = true);
      return;
    }

    if (!mounted) {
      _guardando = false;
      return;
    }
    setState(() => _autovalidar = true);

    final email = formatearEmail(_emailController.text);
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
          throw Exception(kMensajeEmailDuplicado);
        }
      }

      final registrado = Registrado(
        id: '',
        eventoId: widget.eventoId,
        nombreCompleto: formatearNombreCompleto(_nombreController.text),
        email: email,
        acreditado: _acreditarAhora,
        rut: requiereCertificacion ? _rutController.text.trim() : null,
        patente: requiereCertificacion ? _patenteController.text.trim() : null,
        empresa: formatearEmpresa(_empresaController.text),
        cargo: formatearCargo(_cargoController.text),
        telefono: telefonoInternacional(_telefonoController.text, _pais),
        ingresadoPor: userId,
      );

      var correoEnviado = false;
      if (isOnline) {
        final repo = ref.read(registradosRepositoryProvider);
        final creado = await repo.crear(registrado);
        try {
          await repo.enviarQrPorEmail(creado, nombreEvento: nombreEvento);
          correoEnviado = true;
        } catch (e) {
          debugPrint('enviar-qr tras registro manual falló: $e');
        }
      } else {
        await ref.read(syncQueueServiceProvider.notifier).enqueueInsert(
              table: SupabaseTables.registrados,
              payload: registrado.toInsertMap(),
            );
      }

      ref.invalidate(registradosPorEventoProvider(widget.eventoId));

      if (mounted) {
        final mensaje = !isOnline
            ? 'Guardado en modo local. Se subirá solo. El QR se podrá enviar al sincronizar.'
            : correoEnviado
                ? 'Registrado con éxito. QR enviado a $email.'
                : 'Registrado con éxito, pero no se pudo enviar el QR por email.';
        showAppSnackBar(context, mensaje, isError: isOnline && !correoEnviado);
        _formKey.currentState!.reset();
        _nombreController.clear();
        _emailController.clear();
        _empresaController.clear();
        _cargoController.clear();
        _telefonoController.clear();
        _rutController.clear();
        _patenteController.clear();
        setState(() {
          _acreditarAhora = false;
          _pais = kPaisTelefonoChile;
          _autovalidar = false;
        });
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
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.xl,
                    AppSpacing.screenH,
                    AppSpacing.xxxl,
                  ),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _autovalidar
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CamposRegistroAsistente(
                          nombreController: _nombreController,
                          emailController: _emailController,
                          empresaController: _empresaController,
                          cargoController: _cargoController,
                          telefonoController: _telefonoController,
                          pais: _pais,
                          onPaisChanged: (pais) => setState(() => _pais = pais),
                          enabled: !_guardando,
                          mostrarCertificacion: requiereCertificacion,
                          rutController: _rutController,
                          patenteController: _patenteController,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _ToggleRow(
                          title: 'Acreditar de inmediato',
                          subtitle: 'Marca al asistente como acreditado al guardar',
                          value: _acreditarAhora,
                          onChanged: _guardando
                              ? (_) {}
                              : (v) => setState(() => _acreditarAhora = v),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        PrimaryGradientButton(
                          label: 'Guardar registro',
                          loading: _guardando,
                          onPressed: _guardando
                              ? null
                              : () => _guardar(
                                    requiereCertificacion: requiereCertificacion,
                                    nombreEvento: evento.nombre,
                                  ),
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

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          NexusToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
