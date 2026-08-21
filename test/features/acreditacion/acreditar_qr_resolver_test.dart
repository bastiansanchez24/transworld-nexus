import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/data/models/lead_existente.dart';
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

  const leadLocal = LeadExistente(leadId: 'lead-cache', esPropio: true);
  const leadServidor = LeadExistente(leadId: 'lead-sv', esPropio: true);

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

  test('el mismo QR con red consulta al servidor en cada lectura', () async {
    var servidor = 0;
    for (var i = 0; i < 5; i++) {
      await resolverRegistradoParaAcreditacion(
        hayRed: true,
        enCache: fila(acreditado: i > 0),
        obtenerDelServidor: () async {
          servidor++;
          return fila(acreditado: servidor > 1);
        },
        escribirCache: (_) async {},
      );
    }

    expect(servidor, 5);
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

  test(
    'con red el lead se pide al servidor aunque la caché ya lo tenga',
    () async {
      var servidor = 0;
      var cache = 0;
      final hallado = await resolverLeadExistenteParaCaptura(
        hayRed: true,
        email: 'ana@empresa.com',
        buscarEnServidor: () async {
          servidor++;
          return leadServidor;
        },
        buscarEnCache: () async {
          cache++;
          return leadLocal;
        },
      );

      expect(servidor, 1);
      expect(cache, 0);
      expect(hallado?.leadId, 'lead-sv');
    },
  );

  test('con red un miss del servidor no se tapa con un lead de caché', () async {
    final hallado = await resolverLeadExistenteParaCaptura(
      hayRed: true,
      email: 'ana@empresa.com',
      buscarEnServidor: () async => null,
      buscarEnCache: () async => leadLocal,
    );

    expect(hallado, isNull);
  });

  test('el mismo QR con red consulta el lead en cada lectura', () async {
    var servidor = 0;
    for (var i = 0; i < 5; i++) {
      await resolverLeadExistenteParaCaptura(
        hayRed: true,
        email: 'ana@empresa.com',
        buscarEnServidor: () async {
          servidor++;
          return i == 0 ? null : leadServidor;
        },
        buscarEnCache: () async => leadLocal,
      );
    }

    expect(servidor, 5);
  });

  test('sin red el lead sale de la caché y no llama al servidor', () async {
    var servidor = 0;
    final hallado = await resolverLeadExistenteParaCaptura(
      hayRed: false,
      email: 'ana@empresa.com',
      buscarEnServidor: () async {
        servidor++;
        return leadServidor;
      },
      buscarEnCache: () async => leadLocal,
    );

    expect(servidor, 0);
    expect(hallado?.leadId, 'lead-cache');
  });

  test('si el GET de lead falla se usa la caché', () async {
    final hallado = await resolverLeadExistenteParaCaptura(
      hayRed: true,
      email: 'ana@empresa.com',
      buscarEnServidor: () async => throw Exception('red'),
      buscarEnCache: () async => leadLocal,
    );

    expect(hallado?.leadId, 'lead-cache');
  });

  test('sin email no consulta servidor ni caché', () async {
    var servidor = 0;
    var cache = 0;
    final hallado = await resolverLeadExistenteParaCaptura(
      hayRed: true,
      email: '  ',
      buscarEnServidor: () async {
        servidor++;
        return leadServidor;
      },
      buscarEnCache: () async {
        cache++;
        return leadLocal;
      },
    );

    expect(hallado, isNull);
    expect(servidor, 0);
    expect(cache, 0);
  });
}
