import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/supabase/supabase_client_provider.dart';
import 'env.dart';

/// Servicios que `main()` no debe esperar antes del primer frame.
///
/// En Android el splash nativo (Android 12+) se queda en pantalla hasta que
/// Flutter pinta: si `runApp` espera a Supabase, el logo del sistema parece
/// congelado varios segundos. El Lottie de `/splash` corre en paralelo.
class AppBootstrap {
  const AppBootstrap({required this.sharedPreferences});

  final SharedPreferences sharedPreferences;
}

final appBootstrapProvider = FutureProvider<AppBootstrap>((ref) async {
  await Env.load();
  await initializeDateFormatting('es');
  await initSupabase();
  final sharedPreferences = await SharedPreferences.getInstance();
  return AppBootstrap(sharedPreferences: sharedPreferences);
});
