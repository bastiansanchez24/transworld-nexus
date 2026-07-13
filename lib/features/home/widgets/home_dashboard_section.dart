import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
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
          const _SectionLabel('RESUMEN'),
          const SizedBox(height: AppSpacing.sm),
          _KpiGrid(data: data),
          const SizedBox(height: AppSpacing.lg),
          const _SectionLabel('CALENDARIO DE EVENTOS'),
          const SizedBox(height: AppSpacing.sm),
          _EventosCalendario(data: data),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});

  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Eventos',
                valor: '${data.totalEventos}',
                icon: Icons.event_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _KpiCard(
                label: 'Próximos',
                valor: '${data.eventosProximos}',
                icon: Icons.upcoming_rounded,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Registrados',
                valor: '${data.totalRegistrados}',
                icon: Icons.people_outline_rounded,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _KpiCard(
                label: '% Acreditación',
                valor:
                    '${(data.porcentajeAcreditacion * 100).toStringAsFixed(0)}%',
                icon: Icons.verified_outlined,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Activos',
                valor: '${data.eventosActivos}',
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _KpiCard(
                label: 'Este mes',
                valor: '${data.eventosEsteMes}',
                icon: Icons.calendar_month_rounded,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.valor,
    required this.icon,
    required this.color,
  });

  final String label;
  final String valor;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              valor,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _cambiarMes(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    _capitalize(
                      DateFormat('MMMM yyyy', 'es').format(_mesVisible),
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _cambiarMes(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: const [
                _DiaSemanaLabel('L'),
                _DiaSemanaLabel('M'),
                _DiaSemanaLabel('M'),
                _DiaSemanaLabel('J'),
                _DiaSemanaLabel('V'),
                _DiaSemanaLabel('S'),
                _DiaSemanaLabel('D'),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _CalendarioGrid(
              mes: _mesVisible,
              eventosPorDia: eventosPorDia,
              diaSeleccionado: _diaSeleccionado,
              onDiaTap: (dia) => setState(() => _diaSeleccionado = dia),
            ),
            const Divider(height: AppSpacing.xxl),
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
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  String _formatDia(DateTime dia) =>
      DateFormat('d MMM', 'es').format(dia);
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
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
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
      celdas.add(const SizedBox());
    }
    for (var dia = 1; dia <= diasEnMes; dia++) {
      final fecha = DateTime(mes.year, mes.month, dia);
      final tieneEventos = eventosPorDia.containsKey(dia);
      final esHoy = fecha == hoySolo;
      final seleccionado = diaSeleccionado != null &&
          diaSeleccionado!.year == fecha.year &&
          diaSeleccionado!.month == fecha.month &&
          diaSeleccionado!.day == fecha.day;
      final esPasado = fecha.isBefore(hoySolo);

      celdas.add(
        GestureDetector(
          onTap: () => onDiaTap(fecha),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: seleccionado
                  ? AppColors.primary
                  : esHoy
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : null,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dia',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: esHoy || seleccionado
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: seleccionado
                        ? Colors.white
                        : esPasado
                            ? AppColors.textSecondary
                            : AppColors.primaryDark,
                  ),
                ),
                if (tieneEventos)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: seleccionado
                          ? Colors.white
                          : esPasado
                              ? AppColors.textSecondary
                              : AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(height: 7),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1,
      children: celdas,
    );
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
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
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
                  color: pasado ? AppColors.textSecondary : AppColors.accent,
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
                      style: const TextStyle(fontWeight: FontWeight.w600),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Text(
                    'Inactivo',
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
