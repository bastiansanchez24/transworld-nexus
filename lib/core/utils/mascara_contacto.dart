/// Enmascarado del contacto de un lead para los roles que no pueden verlo
/// (`user` y `externo`). Es una capa de presentación: el valor real sigue
/// llegando al cliente y solo se pinta oculto.
library;

const _relleno = '****';

/// Deja visibles los dos primeros caracteres de la parte local y conserva el
/// dominio: `maria.gonzalez@transworld.com` → `ma****@transworld.com`.
///
/// El relleno es de largo fijo para no delatar el largo del original.
String enmascararEmail(String? email) {
  final valor = email?.trim() ?? '';
  if (valor.isEmpty) return '';

  final corte = valor.lastIndexOf('@');
  final local = corte <= 0 ? valor : valor.substring(0, corte);
  final dominio = corte <= 0 ? '' : valor.substring(corte);

  if (local.length <= 2) return '**$dominio';
  return '${local.substring(0, 2)}$_relleno$dominio';
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
