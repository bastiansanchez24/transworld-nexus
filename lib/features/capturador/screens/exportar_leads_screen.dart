import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/offline_guard.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../core/widgets/require_permission.dart';
import '../../../data/repositories/storage_repository.dart';
import '../../auth/providers/auth_providers.dart';
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
    if (!requireOnline(context, ref)) return;
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
      final leads = await ref.read(
        leadsPorEventoProvider(widget.eventoId).future,
      );
      final evento = await ref.read(
        eventoLeadByIdProvider(widget.eventoId).future,
      );

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

      // Un XLSX puede abrirse días después. Las fotos privadas se entregan
      // mediante enlaces firmados por 7 días y nunca se persisten en la DB.
      final storage = ref.read(storageRepositoryProvider);
      final leadsExportables = await Future.wait(
        leads.map((lead) async {
          final fotos = await Future.wait(
            lead.fotosUrls.map(
              (foto) => storage.resolverFotoLead(
                foto,
                expiresInSeconds: 7 * 24 * 60 * 60,
              ),
            ),
          );
          return lead.copyWith(fotosUrls: fotos);
        }),
      );
      final bytes = _service.generar(leadsExportables);
      final nombreArchivo =
          '${evento.nombre.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_leads.xlsx';

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
      deniedMessage: 'Tu rol no permite exportar datos de leads.',
      builder: (_) => AppScaffold(
        title: 'Importar o exportar',
        body: Padding(
          padding: AppSpacing.form,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Exportación'),
                    const SizedBox(height: 10),
                    const Text(
                      'Descarga la lista de leads de esta actividad para '
                      'guardarla o enviarla a quien necesites.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    PrimaryGradientButton(
                      label: 'Exportar todos los leads',
                      loading: _generando,
                      onPressed: _generando ? null : _exportar,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
