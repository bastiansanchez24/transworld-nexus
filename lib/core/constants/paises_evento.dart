const kPaisEventoChile = 'Chile';
const kPaisEventoPeru = 'Perú';

/// Países admitidos por eventos de registro y actividades de captura.
const kPaisesEvento = <String>[kPaisEventoChile, kPaisEventoPeru];

/// Normaliza valores históricos sin tilde antes de mostrarlos o persistirlos.
String normalizarPaisEvento(String? raw) {
  final pais = (raw ?? '').trim().toLowerCase();
  if (pais == 'perú' || pais == 'peru') return kPaisEventoPeru;
  return kPaisEventoChile;
}
