import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Se pone en `true` en el primer frame del splash. No espera a la
/// animación: el Lottie corre en bucle mientras carga, y el router puede
/// irse en cuanto bootstrap/sesión/perfil estén listos.
final splashReadyProvider = StateProvider<bool>((ref) => false);

/// Se pone en `true` si la sesión/perfil no resolvió a tiempo. Evita
/// soft-lock cuando hay sesión restaurada pero el perfil nunca emite
/// data/error.
final splashNavigationTimedOutProvider = StateProvider<bool>((ref) => false);
