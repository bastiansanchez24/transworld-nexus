import '../../data/models/registrado.dart';

/// Lock in-flight del escáner: evita un segundo UPDATE mientras el QR sigue
/// en cuadro, pero no es la verdad permanente de acreditación.
///
/// Si la lista del provider dice `acreditado == false` (p. ej. tras quitar
/// la acreditación en la lista), el id sale del set.
class AcreditacionSesionLock {
  final Set<String> _enVuelo = <String>{};

  void marcarEnVuelo(String id) {
    _enVuelo.add(id.toLowerCase());
  }

  void sincronizarConLista(Iterable<Registrado> lista) {
    for (final registrado in lista) {
      if (!registrado.acreditado) {
        _enVuelo.remove(registrado.id.toLowerCase());
      }
    }
  }

  bool yaEstaAcreditado(Registrado registrado) {
    return registrado.acreditado ||
        _enVuelo.contains(registrado.id.toLowerCase());
  }
}
