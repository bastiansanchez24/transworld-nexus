import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../core/widgets/require_permission.dart';
import '../../auth/providers/auth_providers.dart';
import '../../eventos/providers/eventos_providers.dart';
import '../../registrados/providers/registrados_providers.dart';
import '../services/excel_export_service.dart';
import '../services/export_file_delivery.dart';

class ExportarScreen extends ConsumerStatefulWidget {
  const ExportarScreen({super.key, required this.eventoId});

  final String eventoId;

  @override
  ConsumerState<ExportarScreen> createState() => _ExportarScreenState();
}

class _ExportarScreenState extends ConsumerState<ExportarScreen> {
  static const _service = ExcelExportService();
  bool _generando = false;

  Future<void> _exportar({required bool soloAcreditados}) async {
    if (!ref.read(canExportDataProvider)) {
      showAppSnackBar(
        context,
        'No tienes permiso para exportar datos.',
        isError: true,
      );
      return;
    }
    setState(() => _generando = true);
    try {
      final registrados = await ref.read(
        registradosPorEventoProvider(widget.eventoId).future,
      );
      final evento = await ref.read(eventoByIdProvider(widget.eventoId).future);

      final filtrados = soloAcreditados
          ? registrados.where((r) => r.acreditado).toList()
          : registrados;

      if (filtrados.isEmpty) {
        if (mounted) {
          showAppSnackBar(
            context,
            'No hay datos para exportar.',
            isError: true,
          );
        }
        return;
      }

      final bytes = _service.generar(
        filtrados,
        tituloHoja: soloAcreditados ? 'Acreditados' : 'Registrados',
      );
      final nombreArchivo =
          '${evento.nombre.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_${soloAcreditados ? 'acreditados' : 'registrados'}.xlsx';

      if (!mounted) return;
      final entrega = await entregarExportacion(
        context: context,
        bytes: bytes,
        nombreArchivo: nombreArchivo,
      );
      if (entrega == EntregaExportacion.cancelada || !mounted) return;
      if (entrega == EntregaExportacion.guardada) {
        showAppSnackBar(context, 'Archivo guardado.');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'No se pudo exportar: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RequirePermission(
      allowed: (perfil) => perfil.canExportData,
      deniedMessage: 'Tu rol no permite exportar datos del evento.',
      builder: (_) => AppScaffold(
        title: 'Exportar a Excel',
        body: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.xl,
            AppSpacing.screenH,
            AppSpacing.xxxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.shadowRest,
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel('Exportación'),
                    SizedBox(height: 10),
                    Text(
                      'Descarga la lista de asistentes del evento para '
                      'guardarla o enviarla a quien necesites.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryGradientButton(
                label: 'Exportar todos los registrados',
                loading: _generando,
                onPressed: _generando
                    ? null
                    : () => _exportar(soloAcreditados: false),
              ),
              const SizedBox(height: AppSpacing.md),
              NexusActionRow(
                icon: Symbols.verified_rounded,
                title: 'Exportar solo acreditados',
                subtitle: 'Incluye únicamente asistentes ya acreditados',
                onTap: () {
                  if (!_generando) _exportar(soloAcreditados: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
