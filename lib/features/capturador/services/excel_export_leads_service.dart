import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:intl/intl.dart';

import '../../../core/utils/excel_sheet_styler.dart';
import '../../../data/models/lead.dart';
import '../../../data/models/lead_comentario.dart';

/// Genera el `.xlsx` de leads capturados en un evento.
class ExcelExportLeadsService {
  const ExcelExportLeadsService();

  static const _cabeceras = [
    'Nombre completo',
    'Empresa',
    'Cargo',
    'Teléfono',
    'Email',
    'Descripción',
    'Capturado por',
    'Comentarios',
    'Fecha de captura',
  ];

  /// Hilo de comentarios en una celda: autor y cuerpo, en orden de publicación.
  ///
  /// El autor va delante porque el hilo suele ser una conversación entre el
  /// capturador y quien hace seguimiento, y sin el nombre las respuestas no se
  /// distinguen.
  static String celdaComentarios(List<LeadComentario> comentarios) {
    return comentarios
        .map((c) {
          final autor = c.autorNombre?.trim();
          final cuerpo = c.cuerpo.trim();
          return autor == null || autor.isEmpty ? cuerpo : '$autor: $cuerpo';
        })
        .where((linea) => linea.isNotEmpty)
        .join('\n');
  }

  /// [comentariosPorLead] va indexado por `Lead.id`; un lead sin entrada deja
  /// la celda vacía.
  Uint8List generar(
    List<Lead> leads, {
    String tituloHoja = 'Leads',
    Map<String, List<LeadComentario>> comentariosPorLead = const {},
  }) {
    final excel = xls.Excel.createExcel();
    final nombreHojaOriginal = excel.getDefaultSheet()!;
    excel.rename(nombreHojaOriginal, tituloHoja);
    final sheet = excel[tituloHoja];

    sheet.appendRow([for (final h in _cabeceras) xls.TextCellValue(h)]);

    final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');
    for (final lead in leads) {
      sheet.appendRow([
        xls.TextCellValue(lead.nombreCompleto),
        xls.TextCellValue(lead.empresa ?? ''),
        xls.TextCellValue(lead.cargo ?? ''),
        xls.TextCellValue(lead.telefono ?? ''),
        xls.TextCellValue(lead.email ?? ''),
        xls.TextCellValue(lead.descripcion ?? ''),
        xls.TextCellValue(lead.vendedorNombre ?? ''),
        xls.TextCellValue(
          celdaComentarios(comentariosPorLead[lead.id] ?? const []),
        ),
        xls.TextCellValue(
          lead.createdAt != null ? formatoFecha.format(lead.createdAt!) : '',
        ),
      ]);
    }

    ExcelSheetStyler.aplicar(
      sheet: sheet,
      cabeceras: _cabeceras,
      filasDatos: leads.length,
    );

    final bytes = excel.encode();
    if (bytes == null) throw Exception('No se pudo generar el archivo Excel.');
    return ExcelSheetStyler.congelarPrimeraFila(Uint8List.fromList(bytes));
  }
}
