/// Enmascarado del contacto de leads y registrados para los roles que no pueden
/// verlo (`user` y `externo`). Es una capa de presentación: el valor real sigue
/// llegando al cliente y solo se pinta oculto.
library;

const _relleno = '****';

/// Deja visibles los dos primeros caracteres de la parte local y del dominio,
/// conservando la extensión: `maria.gonzalez@transworld.com` →
/// `ma****@tr****.com`.
///
/// El relleno es de largo fijo para no delatar el largo del original.
String enmascararEmail(String? email) {
  final valor = email?.trim() ?? '';
  if (valor.isEmpty) return '';

  final corte = valor.lastIndexOf('@');
  if (corte <= 0) return _mediaCadena(valor);

  return '${_mediaCadena(valor.substring(0, corte))}'
      '@${_dominioEnmascarado(valor.substring(corte + 1))}';
}

/// El dominio se corta por el último punto: así un subdominio queda dentro de
/// la parte oculta y solo sobrevive la extensión (`mail.transworld.com` →
/// `ma****.com`).
String _dominioEnmascarado(String dominio) {
  if (dominio.isEmpty) return '';

  final corte = dominio.lastIndexOf('.');
  if (corte <= 0) return _mediaCadena(dominio);
  return '${_mediaCadena(dominio.substring(0, corte))}'
      '${dominio.substring(corte)}';
}

/// Dos primeros caracteres y relleno. Con dos o menos se oculta entero.
String _mediaCadena(String valor) {
  if (valor.length <= 2) return '**';
  return '${valor.substring(0, 2)}$_relleno';
}

/// Deja visibles los últimos cuatro caracteres: `+56 9 1234 5678` →
/// `***********5678`.
String enmascararTelefono(String? telefono) {
  final valor = telefono?.trim() ?? '';
  if (valor.isEmpty) return '';
  if (valor.length <= 4) return '*' * valor.length;

  final visible = valor.substring(valor.length - 4);
  return '${'*' * (valor.length - 4)}$visible';
}
