import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:intl/intl.dart';

import '../../../data/models/registrado.dart';

/// Genera el `.xlsx` de descarga (registrados o acreditados) a partir de
/// una lista de [Registrado]. Reemplaza a `xlsx.utils.json_to_sheet` /
/// `XLSX.writeFile` del proyecto legado, sin depender de Electron
/// (`window.ipcRenderer`, ver Sección 4.13/17.4 de la auditoría): la
/// entrega del archivo la resuelve `export_file_delivery` (guardar en
/// Windows; guardar o compartir en móvil; compartir en el resto).
class ExcelExportService {
  const ExcelExportService();

  Uint8List generar(List<Registrado> registrados, {required String tituloHoja}) {
    final excel = xls.Excel.createExcel();
    final nombreHojaOriginal = excel.getDefaultSheet()!;
    excel.rename(nombreHojaOriginal, tituloHoja);
    final sheet = excel[tituloHoja];

    sheet.appendRow([
      xls.TextCellValue('Nombre y Apellido'),
      xls.TextCellValue('Email'),
      xls.TextCellValue('Empresa'),
      xls.TextCellValue('Cargo'),
      xls.TextCellValue('Teléfono'),
      xls.TextCellValue('RUT / RUC'),
      xls.TextCellValue('Patente'),
      xls.TextCellValue('Acreditado'),
      xls.TextCellValue('Fecha de registro'),
    ]);

    final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');
    for (final r in registrados) {
      sheet.appendRow([
        xls.TextCellValue(r.nombreCompleto),
        xls.TextCellValue(r.email),
        xls.TextCellValue(r.empresa ?? ''),
        xls.TextCellValue(r.cargo ?? ''),
        xls.TextCellValue(r.telefono ?? ''),
        xls.TextCellValue(r.rut ?? ''),
        xls.TextCellValue(r.patente ?? ''),
        xls.TextCellValue(r.acreditado ? 'Sí' : 'No'),
        xls.TextCellValue(r.createdAt != null ? formatoFecha.format(r.createdAt!) : ''),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('No se pudo generar el archivo Excel.');
    return Uint8List.fromList(bytes);
  }
}
