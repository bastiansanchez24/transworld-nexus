import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/notificacion.dart';
import '../../../data/repositories/notificaciones_repository.dart';
import '../providers/notificaciones_providers.dart';

class NotificacionesScreen extends ConsumerStatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  ConsumerState<NotificacionesScreen> createState() =>
      _NotificacionesScreenState();
}

class _NotificacionesScreenState extends ConsumerState<NotificacionesScreen> {
  bool _marcandoTodas = false;
  bool _eliminando = false;
  final Set<String> _seleccionados = {};

  bool get _modoSeleccion => _seleccionados.isNotEmpty;
  bool get _ocupado => _marcandoTodas || _eliminando;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _marcarTodasAlAbrir());
  }

  Future<void> _marcarTodasAlAbrir() async {
    final lista = ref.read(notificacionesInboxProvider).valueOrNull;
    if (lista == null || lista.isEmpty) return;

    final pendientes = lista.where((n) => !n.leida).map((n) => n.id).toList();
    if (pendientes.isEmpty) return;

    setState(() => _marcandoTodas = true);
    try {
      await ref
          .read(notificacionesRepositoryProvider)
          .marcarTodasLeidas(pendientes);
      ref.invalidate(notificacionesInboxProvider);
    } finally {
      if (mounted) setState(() => _marcandoTodas = false);
    }
  }

  void _activarSeleccion(String id) {
    setState(() => _seleccionados.add(id));
  }

  void _alternarSeleccion(String id) {
    setState(() {
      if (_seleccionados.contains(id)) {
        _seleccionados.remove(id);
      } else {
        _seleccionados.add(id);
      }
    });
  }

  Future<void> _eliminar(List<NotificacionInbox> lista) async {
    if (_ocupado || lista.isEmpty) return;

    final esSeleccion = _seleccionados.isNotEmpty;
    final cantidad = esSeleccion ? _seleccionados.length : lista.length;

    final confirmado = await confirmDialog(
      context,
      title: esSeleccion ? 'Eliminar seleccionadas' : 'Eliminar todas',
      message: esSeleccion
          ? '¿Deseas eliminar $cantidad notificación(es) seleccionada(s)?'
          : '¿Deseas eliminar todas las notificaciones?',
      confirmLabel: 'Eliminar',
    );
    if (!confirmado || !mounted) return;

    setState(() => _eliminando = true);
    try {
      final repo = ref.read(notificacionesRepositoryProvider);
      if (esSeleccion) {
        await repo.ocultarNotificaciones(_seleccionados.toList());
      } else {
        await repo.ocultarTodasNotificaciones();
      }
      ref.invalidate(notificacionesInboxProvider);
      if (mounted) setState(_seleccionados.clear);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'No se pudieron eliminar las notificaciones.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _eliminando = false);
    }
  }

  String _formatoFecha(DateTime? fecha) {
    if (fecha == null) return '';
    final local = fecha.toLocal();
    final ahora = DateTime.now();
    final diff = ahora.difference(local);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inHours < 1) return 'Hace ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} d';
    return DateFormat('d MMM · HH:mm', 'es').format(local);
  }

  List<Widget> _accionesCabecera(List<NotificacionInbox> lista) {
    if (lista.isEmpty) {
      if (_marcandoTodas) {
        return [
          const NexusHeaderAction(
            icon: Symbols.delete_outline_rounded,
            loading: true,
            onTap: null,
          ),
        ];
      }
      return const [];
    }

    return [
      NexusHeaderAction(
        icon: Symbols.delete_outline_rounded,
        tooltip: _modoSeleccion ? 'Eliminar seleccionadas' : 'Eliminar todas',
        danger: true,
        loading: _eliminando,
        onTap: _ocupado ? null : () => _eliminar(lista),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final inboxAsync = ref.watch(notificacionesInboxProvider);

    return AppScaffold(
      title: _modoSeleccion ? null : 'Notificaciones',
      titleWidget: _modoSeleccion
          ? Text(
              '${_seleccionados.length} seleccionada(s)',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            )
          : null,
      actions: inboxAsync.maybeWhen(
        data: _accionesCabecera,
        orElse: () => const [],
      ),
      body: inboxAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'No se pudieron cargar las notificaciones.',
          onRetry: () => ref.invalidate(notificacionesInboxProvider),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return const EmptyStateView(
              icon: Symbols.notifications_rounded,
              message:
                  'Sin notificaciones.\nVerás avisos de registros y hitos de acreditación (20%, 50%, 80%, 100%) aquí.',
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(notificacionesInboxProvider);
              await ref.read(notificacionesInboxProvider.future);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: lista.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, index) {
                final item = lista[index];
                final seleccionada = _seleccionados.contains(item.id);
                return _NotificacionTile(
                  notificacion: item,
                  fecha: _formatoFecha(item.createdAt),
                  seleccionada: seleccionada,
                  modoSeleccion: _modoSeleccion,
                  onLongPress: _ocupado
                      ? null
                      : () => _activarSeleccion(item.id),
                  onTap: _ocupado
                      ? null
                      : _modoSeleccion
                      ? () => _alternarSeleccion(item.id)
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

IconData _iconoParaTipo(TipoNotificacion tipo) {
  if (tipo.esAcreditacion) {
    return Symbols.verified_rounded;
  }
  return Symbols.person_add_rounded;
}

class _NotificacionTile extends StatelessWidget {
  const _NotificacionTile({
    required this.notificacion,
    required this.fecha,
    required this.seleccionada,
    required this.modoSeleccion,
    this.onTap,
    this.onLongPress,
  });

  final NotificacionInbox notificacion;
  final String fecha;
  final bool seleccionada;
  final bool modoSeleccion;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final contenido = AnimatedContainer(
      duration: AppMotion.toggle,
      curve: AppMotion.ease,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        color: seleccionada ? AppColors.tintNavy : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: seleccionada ? AppColors.primaryLight : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: notificacion.leida
                  ? AppColors.surfaceMuted
                  : AppColors.tintNavy,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              modoSeleccion
                  ? (seleccionada
                        ? Symbols.check_circle_rounded
                        : Symbols.radio_button_unchecked_rounded)
                  : _iconoParaTipo(notificacion.tipo),
              size: modoSeleccion ? 22 : 20,
              color: modoSeleccion
                  ? (seleccionada ? AppColors.primary : AppColors.textTertiary)
                  : notificacion.leida
                  ? AppColors.textSecondary
                  : (notificacion.tipo.esAcreditacion
                        ? AppColors.success
                        : AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notificacion.cuerpo,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: notificacion.leida
                        ? FontWeight.w500
                        : FontWeight.w700,
                    color: AppColors.ink,
                    height: 1.35,
                  ),
                ),
                if (fecha.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    fecha,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null && onLongPress == null) {
      return contenido;
    }

    return Pressable(onTap: onTap, onLongPress: onLongPress, child: contenido);
  }
}
