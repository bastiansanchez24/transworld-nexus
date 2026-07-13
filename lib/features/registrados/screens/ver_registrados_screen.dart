import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/registrado.dart';
import '../../../data/repositories/registrados_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../eventos/providers/eventos_providers.dart';
import '../providers/registrados_providers.dart';

enum _Filtro { todos, acreditados, pendientes }

class VerRegistradosScreen extends ConsumerStatefulWidget {
  const VerRegistradosScreen({super.key, required this.eventoId});

  final String eventoId;

  @override
  ConsumerState<VerRegistradosScreen> createState() => _VerRegistradosScreenState();
}

class _VerRegistradosScreenState extends ConsumerState<VerRegistradosScreen> {
  _Filtro _filtro = _Filtro.todos;
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final registradosAsync = ref.watch(registradosPorEventoProvider(widget.eventoId));

    return AppScaffold(
      title: 'Registrados',
      headerBottom: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Buscar...',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            prefixIcon:
                const Icon(Icons.search, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surfaceMuted,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
          onChanged: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<_Filtro>(
              segments: const [
                ButtonSegment(value: _Filtro.todos, label: Text('Todos')),
                ButtonSegment(value: _Filtro.acreditados, label: Text('Acreditados')),
                ButtonSegment(value: _Filtro.pendientes, label: Text('Pendientes')),
              ],
              selected: {_filtro},
              onSelectionChanged: (s) => setState(() => _filtro = s.first),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(registradosPorEventoProvider(widget.eventoId)),
              child: registradosAsync.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  message: 'No se pudo cargar la lista.',
                  onRetry: () => ref.invalidate(registradosPorEventoProvider(widget.eventoId)),
                ),
                data: (registrados) {
                  final filtrados = registrados.where((r) {
                    if (_filtro == _Filtro.acreditados && !r.acreditado) return false;
                    if (_filtro == _Filtro.pendientes && r.acreditado) return false;
                    if (_busqueda.isEmpty) return true;
                    return r.nombreCompleto.toLowerCase().contains(_busqueda) ||
                        r.email.toLowerCase().contains(_busqueda);
                  }).toList();

                  if (filtrados.isEmpty) {
                    return const EmptyStateView(
                      icon: Icons.people_outline_rounded,
                      message: 'No hay registrados con estos filtros.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtrados.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _RegistradoTile(
                      registrado: filtrados[index],
                      eventoId: widget.eventoId,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistradoTile extends ConsumerWidget {
  const _RegistradoTile({required this.registrado, required this.eventoId});

  final Registrado registrado;
  final String eventoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esAdmin = ref.watch(isAdminProvider);

    return Card(
      child: ListTile(
        onTap: (esAdmin || !registrado.pendienteDeSincronizar)
            ? () => context.push(RoutePaths.editarRegistrado(eventoId, registrado.id))
            : null,
        title: Text(registrado.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [registrado.email, registrado.empresa].where((s) => s != null && s.isNotEmpty).join(' · '),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (registrado.emailConfirmacionEnviado)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Tooltip(
                  message: 'QR enviado por email',
                  child: Icon(Icons.mark_email_read_outlined,
                      size: 18, color: AppColors.textSecondary),
                ),
              ),
            IconButton(
              tooltip: 'Código QR de acreditación',
              icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
              onPressed: () => _mostrarQr(context, ref),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  registrado.acreditado ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: registrado.acreditado ? AppColors.accent : AppColors.textSecondary,
                ),
                if (registrado.pendienteDeSincronizar)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text('Pendiente',
                        style: TextStyle(fontSize: 10, color: AppColors.warning)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarQr(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _QrSheet(registrado: registrado, eventoId: eventoId),
    );
  }
}

/// QR de acreditación de un registrado (codifica `registrados.id`, lo que
/// lee `AcreditarQrScreen`). Permite además enviarlo al correo del asistente
/// mediante la Edge Function `enviar-qr` (regla 6.7 de la documentación de
/// negocio; en el legado esta función existía pero acá nunca se invocaba).
class _QrSheet extends ConsumerStatefulWidget {
  const _QrSheet({required this.registrado, required this.eventoId});

  final Registrado registrado;
  final String eventoId;

  @override
  ConsumerState<_QrSheet> createState() => _QrSheetState();
}

class _QrSheetState extends ConsumerState<_QrSheet> {
  bool _enviando = false;

  Future<void> _enviarPorEmail() async {
    setState(() => _enviando = true);
    try {
      final evento = await ref.read(eventoByIdProvider(widget.eventoId).future);
      await ref
          .read(registradosRepositoryProvider)
          .enviarQrPorEmail(widget.registrado, nombreEvento: evento.nombre);
      ref.invalidate(registradosPorEventoProvider(widget.eventoId));
      if (mounted) {
        Navigator.of(context).pop();
        showAppSnackBar(context, 'QR enviado a ${widget.registrado.email}.');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'No se pudo enviar el QR por email.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final r = widget.registrado;
    // Un registro que solo existe en la cola local todavía no tiene id real
    // en el servidor: su QR no serviría para acreditar ni para el email.
    final puedeEnviar = isOnline && !r.pendienteDeSincronizar;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(r.nombreCompleto, style: Theme.of(context).textTheme.titleLarge),
            Text(r.email, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            if (r.pendienteDeSincronizar)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Este registro aún no se sincroniza con el servidor; '
                  'su QR estará disponible cuando vuelva la conexión.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.warning),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: QrImageView(
                  data: r.id,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: (_enviando || !puedeEnviar) ? null : _enviarPorEmail,
              icon: _enviando
                  ? const ButtonProgress()
                  : const Icon(Icons.outgoing_mail),
              label: Text(
                r.emailConfirmacionEnviado ? 'Reenviar por email' : 'Enviar por email',
              ),
            ),
            if (!isOnline)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('El envío por email requiere conexión.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
          ],
        ),
      ),
    );
  }
}
