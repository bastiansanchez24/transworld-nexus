import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as xls;

/// Estilo compartido para exportaciones `.xlsx` (registrados, leads, etc.).
///
/// Colores anclados a la marca Transworld: navy `#203E6D` + lima `#B1F22A`
/// (ver [AppColors] en `app_theme.dart`).
class ExcelSheetStyler {
  ExcelSheetStyler._();

  // Navy logo / tinta / tinte — mismos hex que AppColors (sin depender de Flutter).
  static final _navy = xls.ExcelColor.fromHexString('#203E6D');
  static final _ink = xls.ExcelColor.fromHexString('#14253F');
  static final _tintNavy = xls.ExcelColor.fromHexString('#E8EDF5');
  static final _lima = xls.ExcelColor.fromHexString('#B1F22A');
  static final _white = xls.ExcelColor.white;

  static final _bordeLima = xls.Border(
    borderStyle: xls.BorderStyle.Thin,
    borderColorHex: _lima,
  );

  static final _bordeSuave = xls.Border(
    borderStyle: xls.BorderStyle.Thin,
    borderColorHex: xls.ExcelColor.fromHexString('#E3E9F1'),
  );

  /// Estiliza la hoja ya poblada: cabecera navy, filas intercaladas,
  /// anchos según el texto de cada cabecera y fila 1 congelada al guardar.
  static void aplicar({
    required xls.Sheet sheet,
    required List<String> cabeceras,
    required int filasDatos,
  }) {
    final columnas = cabeceras.length;
    final headerStyle = xls.CellStyle(
      backgroundColorHex: _navy,
      fontColorHex: _white,
      bold: true,
      horizontalAlign: xls.HorizontalAlign.Center,
      verticalAlign: xls.VerticalAlign.Center,
      bottomBorder: _bordeLima,
      leftBorder: _bordeLima,
      rightBorder: _bordeLima,
      topBorder: _bordeLima,
    );

    final filaPar = xls.CellStyle(
      backgroundColorHex: _white,
      fontColorHex: _ink,
      verticalAlign: xls.VerticalAlign.Center,
      leftBorder: _bordeSuave,
      rightBorder: _bordeSuave,
      topBorder: _bordeSuave,
      bottomBorder: _bordeSuave,
    );

    final filaImpar = xls.CellStyle(
      backgroundColorHex: _tintNavy,
      fontColorHex: _ink,
      verticalAlign: xls.VerticalAlign.Center,
      leftBorder: _bordeSuave,
      rightBorder: _bordeSuave,
      topBorder: _bordeSuave,
      bottomBorder: _bordeSuave,
    );

    for (var col = 0; col < columnas; col++) {
      sheet
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
          .cellStyle = headerStyle;
      sheet.setColumnWidth(col, _anchoParaCabecera(cabeceras[col]));
    }

    for (var row = 1; row <= filasDatos; row++) {
      final estilo = row.isOdd ? filaPar : filaImpar;
      for (var col = 0; col < columnas; col++) {
        sheet
            .cell(
              xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
            )
            .cellStyle = estilo;
      }
    }
  }

  /// Congela la primera fila del workbook generado (`ySplit=1`).
  ///
  /// El paquete `excel` no expone freeze panes; se parchea el XML del `.xlsx`.
  static Uint8List congelarPrimeraFila(Uint8List bytes) {
    final decoded = ZipDecoder().decodeBytes(bytes);
    final out = Archive();

    for (final file in decoded) {
      if (!file.isFile ||
          !file.name.startsWith('xl/worksheets/') ||
          !file.name.endsWith('.xml')) {
        out.addFile(file);
        continue;
      }

      final original = utf8.decode(file.content as List<int>);
      final patched = _inyectarFreezePane(original);
      final encoded = utf8.encode(patched);
      out.addFile(ArchiveFile(file.name, encoded.length, encoded));
    }

    final zipped = ZipEncoder().encode(out);
    if (zipped == null) {
      throw Exception('No se pudo aplicar la fila congelada al Excel.');
    }
    return Uint8List.fromList(zipped);
  }

  /// Ancho en unidades Excel ≈ caracteres de la cabecera, con padding y tope.
  static double _anchoParaCabecera(String texto) {
    final estimado = texto.trim().length * 1.35 + 3;
    return estimado.clamp(12.0, 42.0);
  }

  static String _inyectarFreezePane(String worksheetXml) {
    // Caso típico del template de `excel`: <sheetView workbookViewId="0"/>
    final selfClosing = RegExp(r'<sheetView([^>]*)/>');
    if (selfClosing.hasMatch(worksheetXml)) {
      return worksheetXml.replaceFirstMapped(selfClosing, (m) {
        final attrs = m.group(1) ?? '';
        return '<sheetView$attrs>'
            '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
            '<selection pane="bottomLeft" activeCell="A2" sqref="A2"/>'
            '</sheetView>';
      });
    }

    // Por si ya viene como elemento con cuerpo vacío.
    final openClose = RegExp(r'<sheetView([^>]*)>\s*</sheetView>');
    if (openClose.hasMatch(worksheetXml)) {
      return worksheetXml.replaceFirstMapped(openClose, (m) {
        final attrs = m.group(1) ?? '';
        return '<sheetView$attrs>'
            '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
            '<selection pane="bottomLeft" activeCell="A2" sqref="A2"/>'
            '</sheetView>';
      });
    }

    return worksheetXml;
  }
}
