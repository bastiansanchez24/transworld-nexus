import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/data/models/registrado.dart';
import 'package:transworld_nexus/features/acreditacion/screens/acreditar_qr_screen.dart';

void main() {
  Registrado fila({required bool acreditado}) {
    return Registrado(
      id: 'asistente-1',
      eventoId: 'evento-1',
      nombreCompleto: 'Ana Pérez',
      email: 'ana@empresa.com',
      acreditado: acreditado,
    );
  }

  test('con red no usa el acreditado stale de caché', () async {
    var servidor = 0;
    final fresco = await resolverRegistradoParaAcreditacion(
      hayRed: true,
      enCache: fila(acreditado: false),
      obtenerDelServidor: () async {
        servidor++;
        return fila(acreditado: true);
      },
      escribirCache: (_) async {},
    );

    expect(servidor, 1);
    expect(fresco?.acreditado, isTrue);
  });

  test('con red un GET en false corrige un acreditado local en true', () async {
    final fresco = await resolverRegistradoParaAcreditacion(
      hayRed: true,
      enCache: fila(acreditado: true),
      obtenerDelServidor: () async => fila(acreditado: false),
      escribirCache: (_) async {},
    );

    expect(fresco?.acreditado, isFalse);
  });

  test('sin red no llama al servidor y usa el padrón local', () async {
    var servidor = 0;
    final local = await resolverRegistradoParaAcreditacion(
      hayRed: false,
      enCache: fila(acreditado: false),
      obtenerDelServidor: () async {
        servidor++;
        return fila(acreditado: true);
      },
      escribirCache: (_) async {},
    );

    expect(servidor, 0);
    expect(local?.acreditado, isFalse);
  });
}
