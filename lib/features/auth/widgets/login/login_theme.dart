import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Tokens y overrides de tema exclusivos del flujo de autenticación.
///
/// El login usa una variante "premium" del sistema de diseño global
/// (campos con relleno blanco y borde sutil, radios más generosos,
/// controles de 56 px) sin contaminar el `ThemeData` del resto de la app:
/// se aplica localmente con `Theme(data: LoginTheme.of(context))`.
class LoginTheme {
  LoginTheme._();

  static const fieldRadius = 16.0;
  static const buttonRadius = 18.0;
  static const heroRadius = 28.0;
  static const controlHeight = 56.0;

  /// Fondo blanco de los campos: contraste claro contra [AppColors.background].
  static const fieldFill = AppColors.surface;

  /// Duración/curva únicas de las microinteracciones del flujo (plan:
  /// 250–350 ms, easeOutCubic).
  static const enterDuration = Duration(milliseconds: 320);
  static const keyboardDuration = Duration(milliseconds: 280);
  static const pressDuration = Duration(milliseconds: 120);
  static const curve = Curves.easeOutCubic;

  static OutlineInputBorder _border(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(fieldRadius),
      borderSide: width == 0
          ? BorderSide.none
          : BorderSide(color: color, width: width),
    );
  }

  static ThemeData of(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: fieldFill,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: _border(AppColors.border, 1),
        enabledBorder: _border(AppColors.border, 1),
        focusedBorder: _border(AppColors.primaryDeep, 2),
        errorBorder: _border(AppColors.danger, 1.5),
        focusedErrorBorder: _border(AppColors.danger, 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(controlHeight),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
    );
  }
}
