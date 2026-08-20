import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/app_widgets.dart';
import 'connectivity_service.dart';

/// Texto único para cualquier operación que exige red.
const kMensajeSinConexion = 'No disponible sin conexión a Internet';

/// `true` si hay internet. Si no, muestra el toast unificado y no sigue.
bool requireOnline(BuildContext context, WidgetRef ref) {
  if (ref.read(isOnlineProvider)) return true;
  showOfflineUnavailableToast(context);
  return false;
}

void showOfflineUnavailableToast(BuildContext context) {
  showAppSnackBar(context, kMensajeSinConexion, isError: true);
}
