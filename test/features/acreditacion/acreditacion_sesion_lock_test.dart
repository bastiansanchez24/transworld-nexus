import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/data/models/registrado.dart';
import 'package:transworld_nexus/features/acreditacion/acreditacion_sesion_lock.dart';

void main() {
  Registrado asistente({required bool acreditado}) {
    return Registrado(
      id: 'Asistente-1',
      eventoId: 'evento-1',
      nombreCompleto: 'Ana Pérez',
      email: 'ana@empresa.com',
      acreditado: acreditado,
    );
  }

  test('el lock cubre el QR en cuadro hasta que la lista confirma', () {
    final lock = AcreditacionSesionLock();
    final pendiente = asistente(acreditado: false);

    expect(lock.yaEstaAcreditado(pendiente), isFalse);
    lock.marcarEnVuelo(pendiente.id);
    expect(lock.yaEstaAcreditado(pendiente), isTrue);

    lock.sincronizarConLista([asistente(acreditado: true)]);
    expect(lock.yaEstaAcreditado(asistente(acreditado: true)), isTrue);
  });

  test(
    'acreditar y luego desacreditar en la lista deja de decir que ya ingresó',
    () {
      final lock = AcreditacionSesionLock();
      lock.marcarEnVuelo('asistente-1');

      // Misma instancia de escáner: la lista ya no lo marca acreditado.
      lock.sincronizarConLista([asistente(acreditado: false)]);

      expect(lock.yaEstaAcreditado(asistente(acreditado: false)), isFalse);
    },
  );
}
