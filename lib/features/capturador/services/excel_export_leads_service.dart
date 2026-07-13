import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:intl/intl.dart';

import '../../../data/models/lead.dart';

/// Genera el `.xlsx` de leads capturados en un evento.
class ExcelExportLeadsService {
  const ExcelExportLeadsService();

  Uint8List generar(List<Lead> leads, {String tituloHoja = 'Leads'}) {
    final excel = xls.Excel.createExcel();
    final nombreHojaOriginal = excel.getDefaultSheet()!;
    excel.rename(nombreHojaOriginal, tituloHoja);
    final sheet = excel[tituloHoja];

    sheet.appendRow([
      xls.TextCellValue('Nombre completo'),
      xls.TextCellValue('Empresa'),
      xls.TextCellValue('Cargo'),
      xls.TextCellValue('Teléfono'),
      xls.TextCellValue('Email'),
      xls.TextCellValue('Capturado por'),
      xls.TextCellValue('Fotos (URLs)'),
      xls.TextCellValue('Fecha de captura'),
    ]);

    final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');
    for (final lead in leads) {
      sheet.appendRow([
        xls.TextCellValue(lead.nombreCompleto),
        xls.TextCellValue(lead.empresa ?? ''),
        xls.TextCellValue(lead.cargo ?? ''),
        xls.TextCellValue(lead.telefono ?? ''),
        xls.TextCellValue(lead.email ?? ''),
        xls.TextCellValue(lead.vendedorNombre ?? ''),
        xls.TextCellValue(lead.fotosUrls.join(' | ')),
        xls.TextCellValue(
          lead.createdAt != null ? formatoFecha.format(lead.createdAt!) : '',
        ),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('No se pudo generar el archivo Excel.');
    return Uint8List.fromList(bytes);
  }
}
