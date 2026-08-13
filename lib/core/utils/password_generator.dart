import 'dart:math';

import 'password_policy.dart';

// Alfabeto sin caracteres ambiguos (fuera I, O, l, 0, 1) para que la clave se
// pueda dictar o copiar del correo sin confusiones.
const String _mayusculas = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const String _minusculas = 'abcdefghijkmnopqrstuvwxyz';
const String _numeros = '23456789';
const List<String> _grupos = [
  _mayusculas,
  _minusculas,
  _numeros,
  kPasswordSymbols,
];

/// Genera una contraseña para invitaciones que cumple Auth de Supabase
/// ([validarContrasenaFuerte]): un carácter de cada grupo y el resto al azar.
/// Largo mínimo (8) y símbolos simples para que sea fácil de leer/teclear.
String generarContrasenaInvitacion({int length = kPasswordMinLength}) {
  final largo = length < _grupos.length ? _grupos.length : length;
  final random = Random.secure();
  final todos = _grupos.join();

  final chars = <String>[
    for (final grupo in _grupos) grupo[random.nextInt(grupo.length)],
    for (var i = _grupos.length; i < largo; i++)
      todos[random.nextInt(todos.length)],
  ];

  // Sin barajar, los primeros caracteres seguirían siempre el orden de grupo.
  for (var i = chars.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final tmp = chars[i];
    chars[i] = chars[j];
    chars[j] = tmp;
  }

  return chars.join();
}
