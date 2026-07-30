import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:intl/intl.dart';

import '../../../data/models/lead.dart';
import '../../../data/offline/pending_photo_store.dart';

/// Genera el `.xlsx` de leads capturados en un evento.
class ExcelExportLeadsService {
  const ExcelExportLeadsService();

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

    sheet.appendRow([
      xls.TextCellValue('Nombre completo'),
      xls.TextCellValue('Empresa'),
      xls.TextCellValue('Cargo'),
      xls.TextCellValue('Teléfono'),
      xls.TextCellValue('Email'),
      xls.TextCellValue('Descripción'),
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
        xls.TextCellValue(lead.descripcion ?? ''),
        xls.TextCellValue(lead.vendedorNombre ?? ''),
        xls.TextCellValue(_celdaFotos(lead)),
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
