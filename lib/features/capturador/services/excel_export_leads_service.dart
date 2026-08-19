import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:intl/intl.dart';

import '../../../core/utils/excel_sheet_styler.dart';
import '../../../data/models/lead.dart';
import '../../../data/offline/pending_photo_store.dart';

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
    'Fotos (URLs)',
    'Fecha de captura',
  ];

  /// Una foto capturada sin conexión todavía no tiene URL pública: en la
  /// celda iría una ruta del dispositivo que no le sirve a nadie.
  String _celdaFotos(Lead lead) {
    final subidas = lead.fotosUrls.where((u) => !esFotoLocal(u));
    final pendientes = lead.fotosUrls.where(esFotoLocal).length;
    return [
      ...subidas,
      if (pendientes > 0) '($pendientes pendiente(s) de subir)',
    ].join(' | ');
  }

  Uint8List generar(List<Lead> leads, {String tituloHoja = 'Leads'}) {
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
        xls.TextCellValue(_celdaFotos(lead)),
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
