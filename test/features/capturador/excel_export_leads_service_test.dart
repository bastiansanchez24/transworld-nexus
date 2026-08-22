import 'package:excel/excel.dart' as xls;
import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/data/models/lead.dart';
import 'package:transworld_nexus/data/models/lead_comentario.dart';
import 'package:transworld_nexus/features/capturador/services/excel_export_leads_service.dart';

const _servicio = ExcelExportLeadsService();

Lead _lead(String id, String nombre) =>
    Lead(id: id, eventoId: 'ev-1', nombreCompleto: nombre);

LeadComentario _comentario(String leadId, String autor, String cuerpo) =>
    LeadComentario(
      id: '$leadId-${cuerpo.hashCode}',
      leadId: leadId,
      cuerpo: cuerpo,
      autorNombre: autor,
    );

List<String> _fila(xls.Sheet hoja, int fila) => [
  for (final celda in hoja.rows[fila]) celda?.value?.toString() ?? '',
];

void main() {
  test('la cabecera cambia fotos por comentarios', () {
    final bytes = _servicio.generar([_lead('l1', 'Ana Soto')]);
    final hoja = xls.Excel.decodeBytes(bytes)['Leads'];

    final cabeceras = _fila(hoja, 0);
    expect(cabeceras, contains('Comentarios'));
    expect(cabeceras.where((c) => c.toLowerCase().contains('foto')), isEmpty);
    expect(cabeceras, [
      'Nombre completo',
      'Empresa',
      'Cargo',
      'Teléfono',
      'Email',
      'Descripción',
      'Capturado por',
      'Comentarios',
      'Fecha de captura',
    ]);
  });

  test('el hilo del lead viaja en su celda, en orden y con autor', () {
    final bytes = _servicio.generar(
      [_lead('l1', 'Ana Soto'), _lead('l2', 'Beto Díaz')],
      comentariosPorLead: {
        'l1': [
          _comentario('l1', 'Carla', 'Pidió cotización'),
          _comentario('l1', 'Diego', 'Enviada el martes'),
        ],
      },
    );
    final hoja = xls.Excel.decodeBytes(bytes)['Leads'];

    final columna = _fila(hoja, 0).indexOf('Comentarios');
    expect(
      _fila(hoja, 1)[columna],
      'Carla: Pidió cotización\nDiego: Enviada el martes',
    );
    expect(
      _fila(hoja, 2)[columna],
      isEmpty,
      reason: 'un lead sin comentarios deja la celda vacía',
    );
  });

  test('un comentario sin autor conocido va solo con su cuerpo', () {
    expect(
      ExcelExportLeadsService.celdaComentarios([
        const LeadComentario(id: 'c1', leadId: 'l1', cuerpo: 'Sin autor'),
      ]),
      'Sin autor',
    );
  });
}
