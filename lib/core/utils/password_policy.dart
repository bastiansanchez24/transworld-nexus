/// Política única de contraseñas de la app: alineada con Auth de Supabase
/// (`minimum_password_length = 8` + `lower_upper_letters_digits_symbols`).
/// La usan formularios y el generador (`password_generator.dart`).
library;

/// Largo mínimo exigido por Supabase Auth.
const int kPasswordMinLength = 8;

/// Símbolos aceptados. Se eligieron por ser fáciles de teclear en móvil y
/// seguros tanto en el correo HTML de credenciales como al compartir por texto.
const String kPasswordSymbols = r'!#%$';

/// Texto de ayuda reutilizable para los campos de contraseña.
const String kPasswordHelperText =
    'Mínimo $kPasswordMinLength caracteres, con mayúscula, minúscula, número '
    'y símbolo (! # % \$).';

final RegExp _mayuscula = RegExp(r'[A-Z]');
final RegExp _minuscula = RegExp(r'[a-z]');
final RegExp _numero = RegExp(r'[0-9]');
final RegExp _simbolo = RegExp(r'[!#%$]');

/// Valida que la contraseña cumpla la política. Devuelve `null` si es válida
/// o un mensaje corto para mostrar en el `validator` de un `TextFormField`.
String? validarContrasenaFuerte(String? value) {
  final password = value ?? '';
  if (password.length < kPasswordMinLength) {
    return 'Mínimo $kPasswordMinLength caracteres';
  }
  if (!_mayuscula.hasMatch(password)) return 'Debe incluir una mayúscula';
  if (!_minuscula.hasMatch(password)) return 'Debe incluir una minúscula';
  if (!_numero.hasMatch(password)) return 'Debe incluir un número';
  if (!_simbolo.hasMatch(password)) {
    return 'Debe incluir un símbolo (! # % \$)';
  }
  return null;
}
