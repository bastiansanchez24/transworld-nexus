import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../eventos/providers/eventos_providers.dart';
import '../../registrados/providers/registrados_providers.dart';
import '../services/excel_export_service.dart';

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
    setState(() => _generando = true);
    try {
      final registrados = await ref.read(registradosPorEventoProvider(widget.eventoId).future);
      final evento = await ref.read(eventoByIdProvider(widget.eventoId).future);

      final filtrados = soloAcreditados
          ? registrados.where((r) => r.acreditado).toList()
          : registrados;

      if (filtrados.isEmpty) {
        if (mounted) showAppSnackBar(context, 'No hay datos para exportar.', isError: true);
        return;
      }

      final bytes = _service.generar(filtrados, tituloHoja: soloAcreditados ? 'Acreditados' : 'Registrados');
      final nombreArchivo =
          '${evento.nombre.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_${soloAcreditados ? 'acreditados' : 'registrados'}.xlsx';

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              name: nombreArchivo,
              mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          ],
          fileNameOverrides: [nombreArchivo],
        ),
      );
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'No se pudo exportar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
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
                    'Genera un archivo .xlsx con los datos del evento. '
                    'Se abrirá el selector nativo para guardarlo o compartirlo.',
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
    );
  }
}
