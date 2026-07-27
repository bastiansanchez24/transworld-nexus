import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';

/// Pantalla de arranque mientras se restaura la sesión / perfil.
///
/// Evita mostrar el formulario de login durante el bootstrap cuando ya hay
/// sesión persistida.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: LoadingView(),
    );
  }
}
