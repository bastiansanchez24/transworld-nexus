import 'package:flutter/foundation.dart';

import 'browser_history_stub.dart'
    if (dart.library.js_interop) 'browser_history_web.dart'
    as impl;

/// Sustituto del historial real para las pruebas: en la VM no hay navegador,
/// así que sin esta costura el camino de web quedaría sin cobertura.
@visibleForTesting
bool Function(int pasos)? retrocesoDeHistorialParaPruebas;

/// Retrocede [pasos] entradas del historial del navegador y responde si lo
/// hizo. Siempre `false` fuera de web.
bool retrocederEnHistorial(int pasos) {
  final prueba = retrocesoDeHistorialParaPruebas;
  if (prueba != null) return prueba(pasos);
  return impl.retrocederEnHistorial(pasos);
}
