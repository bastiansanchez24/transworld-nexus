import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/evento.dart';
import '../providers/home_dashboard_providers.dart';

class HomeDashboardSection extends ConsumerWidget {
  const HomeDashboardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(homeDashboardProvider);

    return dashboardAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: LoadingView(message: 'Cargando resumen...'),
      ),
      error: (e, _) => ErrorView(
        message: 'No se pudo cargar el resumen.',
        onRetry: () => ref.invalidate(homeDashboardProvider),
      ),
      data: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Resumen'),
          const SizedBox(height: 12),
          _KpiGrid(data: data),
          const SizedBox(height: AppSpacing.sectionGap),
          const SectionLabel('Calendario de eventos'),
          const SizedBox(height: 12),
          _EventosCalendario(data: data),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});

  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    final cards = [
      (
        '${data.totalEventos}',
        'Eventos',
        Symbols.calendar_month_rounded,
        AppColors.tintNavy,
        AppColors.primary,
      ),
      (
        '${data.eventosProximos}',
        'Próximos',
        Symbols.upcoming_rounded,
        AppColors.successTint,
        AppColors.success,
      ),
      (
        '${data.totalRegistrados}',
        'Registrados',
        Symbols.group_rounded,
        AppColors.tintNavy,
        AppColors.primary,
      ),
      (
        '${(data.porcentajeAcreditacion * 100).toStringAsFixed(0)}%',
        'Acreditación',
        Symbols.verified_rounded,
        AppColors.successTint,
        AppColors.success,
      ),
      (
        '${data.eventosActivos}',
        'Activos',
        Symbols.check_circle_rounded,
        AppColors.successTint,
        AppColors.success,
      ),
      (
        '${data.eventosEsteMes}',
        'Este mes',
        Symbols.event_rounded,
        AppColors.warningTint,
        AppColors.warning,
      ),
    ];

    return Column(
      children: [
        for (var row = 0; row < 3; row++) ...[
          if (row > 0) const SizedBox(height: 12),
          Row(
            children: [
              for (var col = 0; col < 2; col++) ...[
                if (col > 0) const SizedBox(width: 12),
                Expanded(
                  child: StaggeredListItem(
                    index: row * 2 + col,
                    child: StatCard(
                      value: cards[row * 2 + col].$1,
                      label: cards[row * 2 + col].$2,
                      icon: cards[row * 2 + col].$3,
                      tint: cards[row * 2 + col].$4,
                      iconColor: cards[row * 2 + col].$5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _EventosCalendario extends StatefulWidget {
  const _EventosCalendario({required this.data});

  final HomeDashboardData data;

  @override
  State<_EventosCalendario> createState() => _EventosCalendarioState();
}

class _EventosCalendarioState extends State<_EventosCalendario> {
  late DateTime _mesVisible;
  DateTime? _diaSeleccionado;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _mesVisible = DateTime(hoy.year, hoy.month);
    _diaSeleccionado = DateTime(hoy.year, hoy.month, hoy.day);
  }

  void _cambiarMes(int delta) {
    setState(() {
      _mesVisible = DateTime(_mesVisible.year, _mesVisible.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventosDelMes = widget.data.eventosEnMes(_mesVisible);
    final eventosPorDia = <int, List<Evento>>{};
    for (final evento in eventosDelMes) {
      eventosPorDia.putIfAbsent(evento.fecha.day, () => []).add(evento);
    }

    final eventosLista = _diaSeleccionado != null
        ? widget.data.eventosEnDia(_diaSeleccionado!)
        : widget.data.proximosEventos.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.shadowRest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pressable(
                scale: 0.9,
                onTap: () => _cambiarMes(-1),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Symbols.chevron_left_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _capitalize(
                    DateFormat('MMMM yyyy', 'es').format(_mesVisible),
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Pressable(
                scale: 0.9,
                onTap: () => _cambiarMes(1),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Symbols.chevron_right_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              _DiaSemanaLabel('L'),
              _DiaSemanaLabel('M'),
              _DiaSemanaLabel('M'),
              _DiaSemanaLabel('J'),
              _DiaSemanaLabel('V'),
              _DiaSemanaLabel('S'),
              _DiaSemanaLabel('D'),
            ],
          ),
          const SizedBox(height: 4),
          AnimatedSize(
            duration: AppMotion.toggle,
            curve: AppMotion.ease,
            alignment: Alignment.topCenter,
            child: _CalendarioGrid(
              mes: _mesVisible,
              eventosPorDia: eventosPorDia,
              diaSeleccionado: _diaSeleccionado,
              onDiaTap: (dia) => setState(() => _diaSeleccionado = dia),
            ),
          ),
          const Divider(height: AppSpacing.xxl, color: AppColors.divider),
          Text(
            _diaSeleccionado != null
                ? 'Eventos del ${_formatDia(_diaSeleccionado!)}'
                : 'Próximos eventos',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (eventosLista.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'No hay eventos en esta fecha.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            ...eventosLista.map((e) => _EventoCalendarioTile(evento: e)),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  String _formatDia(DateTime dia) => DateFormat('d MMM', 'es').format(dia);
}

class _DiaSemanaLabel extends StatelessWidget {
  const _DiaSemanaLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _CalendarioGrid extends StatelessWidget {
  const _CalendarioGrid({
    required this.mes,
    required this.eventosPorDia,
    required this.diaSeleccionado,
    required this.onDiaTap,
  });

  final DateTime mes;
  final Map<int, List<Evento>> eventosPorDia;
  final DateTime? diaSeleccionado;
  final ValueChanged<DateTime> onDiaTap;

  @override
  Widget build(BuildContext context) {
    final primerDia = DateTime(mes.year, mes.month, 1);
    final diasEnMes = DateTime(mes.year, mes.month + 1, 0).day;
    final offset = primerDia.weekday - 1;
    final hoy = DateTime.now();
    final hoySolo = DateTime(hoy.year, hoy.month, hoy.day);

    final celdas = <Widget>[];
    for (var i = 0; i < offset; i++) {
      celdas.add(const _CeldaCalendarioVacia());
    }
    for (var dia = 1; dia <= diasEnMes; dia++) {
      final fecha = DateTime(mes.year, mes.month, dia);
      final tieneEventos = eventosPorDia.containsKey(dia);
      final esHoy = fecha == hoySolo;
      final seleccionado =
          diaSeleccionado != null &&
          diaSeleccionado!.year == fecha.year &&
          diaSeleccionado!.month == fecha.month &&
          diaSeleccionado!.day == fecha.day;
      final esPasado = fecha.isBefore(hoySolo);

      celdas.add(
        GestureDetector(
          onTap: () => onDiaTap(fecha),
          child: AspectRatio(
            aspectRatio: 1.15,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: esHoy ? AppColors.headerGradient : null,
                color: !esHoy && seleccionado ? AppColors.tintNavy : null,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '$dia',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: esHoy || seleccionado
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: esHoy
                          ? Colors.white
                          : esPasado
                          ? AppColors.textTertiary
                          : AppColors.ink,
                    ),
                  ),
                  if (tieneEventos && !esHoy)
                    Positioned(
                      bottom: 4,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    while (celdas.length % 7 != 0) {
      celdas.add(const _CeldaCalendarioVacia());
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var inicio = 0; inicio < celdas.length; inicio += 7) ...[
          if (inicio > 0) const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = inicio; i < inicio + 7; i++) ...[
                if (i > inicio) const SizedBox(width: 2),
                Expanded(child: celdas[i]),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _CeldaCalendarioVacia extends StatelessWidget {
  const _CeldaCalendarioVacia();

  @override
  Widget build(BuildContext context) {
    return const AspectRatio(aspectRatio: 1.15);
  }
}

class _EventoCalendarioTile extends StatelessWidget {
  const _EventoCalendarioTile({required this.evento});

  final Evento evento;

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat('dd/MM/yyyy').format(evento.fecha);
    final pasado = evento.yaOcurrio;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Pressable(
        onTap: () => context.push(RoutePaths.usarEvento(evento.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: pasado ? AppColors.textTertiary : AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      evento.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      '$fecha · ${evento.lugar ?? evento.pais ?? ''}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!evento.activo)
                const StatusChip(
                  label: 'Inactivo',
                  variant: StatusChipVariant.neutral,
                ),
              const Icon(
                Symbols.chevron_right_rounded,
                color: AppColors.chevronMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
