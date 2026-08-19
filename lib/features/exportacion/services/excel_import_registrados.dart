import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;

import '../../../core/utils/registro_asistente.dart';
import '../../../data/models/registrado.dart';

/// Lee un `.xlsx` de carga masiva y lo convierte en [Registrado]s.
///
/// Columnas reconocidas (insensible a mayúsculas): Nombre y Apellido, Email,
/// Empresa, Cargo, Teléfono, RUT / RUC (opcional), Patente (opcional).
class ExcelImportRegistrados {
  const ExcelImportRegistrados();

  static const descripcionColumnas =
      'Columnas esperadas: Nombre y Apellido, Email, Empresa, Cargo, '
      'Teléfono, RUT / RUC (opcional), Patente (opcional).';

  List<Registrado> parsear(Uint8List bytes, {required String eventoId}) {
    final excel = xls.Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw Exception('El archivo está vacío.');
    }
    final hoja = excel.tables.values.first;
    final filas = hoja.rows;
    if (filas.isEmpty) throw Exception('El archivo está vacío.');

    final encabezados = filas.first.map(_textoDeCelda).toList();

    int indiceDe(String nombre) => encabezados.indexWhere(
      (h) => h.toLowerCase() == nombre.toLowerCase(),
    );

    final iNombre = indiceDe('Nombre y Apellido');
    final iEmail = indiceDe('Email');
    final iEmpresa = indiceDe('Empresa');
    final iCargo = indiceDe('Cargo');
    final iTelefono = indiceDe('Teléfono');
    final iRut = indiceDe('RUT / RUC');
    final iPatente = indiceDe('Patente');

    String celda(List<xls.Data?> fila, int i) =>
        (i == -1 || i >= fila.length) ? '' : _textoDeCelda(fila[i]);

    final registros = <Registrado>[];
    for (final fila in filas.skip(1)) {
      final nombre = celda(fila, iNombre);
      final email = celda(fila, iEmail).toLowerCase();
      if (nombre.isEmpty || email.isEmpty) continue;

      final rutRaw = iRut == -1 ? '' : celda(fila, iRut);
      final patenteRaw = iPatente == -1 ? '' : celda(fila, iPatente);
      if (validarRut(rutRaw, requerido: false) != null) continue;
      if (validarPatente(patenteRaw, requerido: false) != null) continue;

      registros.add(
        Registrado(
          id: '',
          eventoId: eventoId,
          nombreCompleto: nombre,
          email: email,
          empresa: celda(fila, iEmpresa),
          cargo: celda(fila, iCargo),
          telefono: celda(fila, iTelefono),
          rut: rutRaw.isEmpty ? null : formatearRut(rutRaw),
          patente: patenteRaw.isEmpty ? null : formatearPatente(patenteRaw),
          origen: OrigenRegistro.excel,
        ),
      );
    }

    if (registros.isEmpty) {
      throw Exception(
        'No se encontraron filas válidas (revisa los encabezados).',
      );
    }
    return registros;
  }
}

/// El paquete `excel` (v4) modela el valor de cada celda como un
/// `sealed class CellValue`. Se resuelve cada variante en vez de confiar
/// en `toString()` (que en `TextCellValue` envuelve un `TextSpan`).
String _textoDeCelda(xls.Data? celda) {
  final valor = celda?.value;
  return switch (valor) {
    null => '',
    xls.TextCellValue v => (v.value.text ?? '').trim(),
    xls.IntCellValue v => v.value.toString(),
    xls.DoubleCellValue v => v.value.toString(),
    xls.BoolCellValue v => v.value.toString(),
    xls.DateCellValue v => v.asDateTimeLocal().toIso8601String(),
    xls.FormulaCellValue v => v.formula,
    _ => valor.toString(),
  }.trim();
}
