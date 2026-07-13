import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
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
        padding: AppSpacing.screen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Genera un archivo .xlsx con los datos del evento. '
              'Se abrirá el selector nativo para guardarlo o compartirlo.',
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton.icon(
              onPressed: _generando ? null : () => _exportar(soloAcreditados: false),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Exportar todos los registrados'),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _generando ? null : () => _exportar(soloAcreditados: true),
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Exportar solo acreditados'),
            ),
            if (_generando) ...[
              const SizedBox(height: AppSpacing.xxl),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
