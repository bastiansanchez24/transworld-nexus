import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Se pone en `true` cuando el splash animado llega al hold (mark completo).
///
/// El router no abandona `/splash` hasta que esto sea true, para no cortar
/// el draw-on del logo en arranques rápidos.
final splashReadyProvider = StateProvider<bool>((ref) => false);
