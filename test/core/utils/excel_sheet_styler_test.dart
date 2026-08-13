import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as xls;
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/utils/excel_sheet_styler.dart';
import 'package:transworld_nexus/data/models/registrado.dart';
import 'package:transworld_nexus/features/exportacion/services/excel_export_service.dart';

void main() {
  test('exportación de registrados congela la cabecera', () {
    const service = ExcelExportService();
    final bytes = service.generar([
      const Registrado(
        id: '1',
        eventoId: 'e1',
        nombreCompleto: 'Ana Díaz',
        email: 'ana@empresa.cl',
        empresa: 'Transworld',
      ),
      const Registrado(
        id: '2',
        eventoId: 'e1',
        nombreCompleto: 'Pedro Soto',
        email: 'pedro@empresa.cl',
        acreditado: true,
      ),
    ], tituloHoja: 'Registrados');

    final archive = ZipDecoder().decodeBytes(bytes);
    final sheetXml = archive.files.firstWhere(
      (f) => f.name.startsWith('xl/worksheets/') && f.name.endsWith('.xml'),
    );
    final xml = utf8.decode(sheetXml.content as List<int>);

    expect(xml, contains('state="frozen"'));
    expect(xml, contains('ySplit="1"'));

    final reopened = xls.Excel.decodeBytes(bytes);
    expect(reopened.tables.containsKey('Registrados'), isTrue);
    expect(reopened['Registrados'].maxRows, greaterThanOrEqualTo(3));
  });

  test('congelarPrimeraFila inyecta pane en sheetView autocerrado', () {
    const xml =
        '<?xml version="1.0"?><worksheet><sheetViews>'
        '<sheetView workbookViewId="0"/>'
        '</sheetViews></worksheet>';
    final archive = Archive()
      ..addFile(
        ArchiveFile('xl/worksheets/sheet1.xml', xml.length, utf8.encode(xml)),
      )
      ..addFile(ArchiveFile('[Content_Types].xml', 2, utf8.encode('ok')));
    final zipped = Uint8List.fromList(ZipEncoder().encode(archive)!);
    final patched = ExcelSheetStyler.congelarPrimeraFila(zipped);

    final out = ZipDecoder().decodeBytes(patched);
    final content = utf8.decode(
      out.findFile('xl/worksheets/sheet1.xml')!.content as List<int>,
    );
    expect(content, contains('state="frozen"'));
    expect(content, contains('topLeftCell="A2"'));
  });
}
