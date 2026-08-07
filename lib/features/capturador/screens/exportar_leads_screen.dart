import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../exportacion/services/export_file_delivery.dart';
import '../providers/capturador_providers.dart';
import '../services/excel_export_leads_service.dart';

class ExportarLeadsScreen extends ConsumerStatefulWidget {
  const ExportarLeadsScreen({super.key, required this.eventoId});

  final String eventoId;

  @override
  ConsumerState<ExportarLeadsScreen> createState() =>
      _ExportarLeadsScreenState();
}

class _ExportarLeadsScreenState extends ConsumerState<ExportarLeadsScreen> {
  static const _service = ExcelExportLeadsService();
  bool _generando = false;

  Future<void> _exportar() async {
    setState(() => _generando = true);
    try {
      final leads =
          await ref.read(leadsPorEventoProvider(widget.eventoId).future);
      final evento =
          await ref.read(eventoLeadByIdProvider(widget.eventoId).future);

      if (leads.isEmpty) {
        if (mounted) {
          showAppSnackBar(
            context,
            'No hay leads para exportar.',
            isError: true,
          );
        }
        return;
      }

      final bytes = _service.generar(leads);
      final nombreArchivo =
          '${evento.nombre.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_leads.xlsx';

      final entregado = await entregarExportacion(
        bytes: bytes,
        nombreArchivo: nombreArchivo,
      );
      if (!entregado || !mounted) return;
      if (esWindowsApp) {
        showAppSnackBar(context, 'Archivo guardado.');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          'No se pudo exportar: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ayuda = esWindowsApp
        ? 'Genera un archivo .xlsx con los leads capturados en este evento. '
            'Se abrirá el diálogo para guardarlo en tu equipo.'
        : 'Genera un archivo .xlsx con los leads capturados en este evento. '
            'Se abrirá el selector nativo para guardarlo o compartirlo.';

    return AppScaffold(
      title: 'Exportar leads',
      body: Padding(
        padding: AppSpacing.screen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ayuda,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryGradientButton(
              label: _generando ? 'Generando…' : 'Exportar todos los leads',
              loading: _generando,
              onPressed: _generando ? null : _exportar,
            ),
          ],
        ),
      ),
    );
  }
}
