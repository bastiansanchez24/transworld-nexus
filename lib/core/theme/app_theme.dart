import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tw_tokens.dart';

/// Tokens de color Nexus — anclados al mark Transworld (navy + lima).
///
/// Los neutros (texto gris, bordes, chevrons, superficies) **son** los de
/// [TwColors]: una sola escala para toda la app. Lo que sigue teniendo valor
/// propio es la identidad de marca — navy del logo, lima y sus tintes—, que
/// `test/core/theme/app_theme_test.dart` fija a propósito.
class AppColors {
  AppColors._();

  // Brand (muestreados del logo: navy #203E6D · lima #B1F22A).
  static const primary = Color(0xFF203E6D); // logo navy
  static const primaryDeep = Color(0xFF162B4C); // navy-900
  static const primaryLight = Color(0xFF2E568F); // navy-500
  static const accent = Color(0xFFB1F22A); // logo lima
  static const accentGlow = Color(0xFFA0DE2A); // lima glow del motion spec

  // Neutros unificados con el rediseño.
  static const ink = TwColors.ink;
  static const identityInk = ink;
  static const identityAccent = TwColors.brand700;
  static const identityChip = TwColors.blueTint;
  static const textSecondary = TwColors.secondary;
  static const textTertiary = TwColors.muted;
  static const background = TwColors.bg;
  static const surface = TwColors.surface;
  static const border = TwColors.fieldBorder;
  static const placeholder = TwColors.muted;
  static const chevronMuted = TwColors.chevron;
  static const divider = TwColors.border07;
  static const dashedBorder = TwColors.chevron;
  static const toggleOff = TwColors.chevron;

  static const heroNavy = Color(0xFF0C3357);
  static const heroNavyMid = Color(0xFF175E93);
  static const live = TwColors.statusActive;
  static const tintNavy = TwColors.blueTint;
  static const tintLime = Color(0xFFF3FCE0);

  // Semánticos: success en familia lima (más oscuro para texto legible).
  static const success = Color(0xFF6B9E14);
  static const successTint = tintLime;
  static const warning = TwColors.amberInk;
  static const warningTint = TwColors.amberTint;
  static const danger = TwColors.danger;
  static const dangerTint = TwColors.dangerTint;
  static const toastCheck = accent;

  /// Alias de compatibilidad con pantallas legacy.
  static const primaryDark = primaryDeep;
  static const error = danger;
  static const surfaceMuted = tintNavy;

  static const headerGradient = LinearGradient(
    colors: [primaryDeep, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Card de próximo evento del home (150° #0C3357 → #175E93).
  static const heroGradient = LinearGradient(
    colors: [heroNavy, heroNavyMid],
    begin: Alignment(-0.5, -1),
    end: Alignment(0.5, 1),
  );

  // Sombras unificadas con las del rediseño ([TwShadows]).
  static const shadowRest = TwShadows.card;
  static const shadowLifted = TwShadows.card;
  static const shadowFab = TwShadows.primary;
  static const shadowHero = TwShadows.hero;

  static const shadowHeroCard = TwShadows.hero;
  static const shadowToast = TwShadows.toast;

  static const avatarPairs = <(Color, Color)>[
    (tintNavy, primary),
    (tintLime, success),
    (Color(0xFFFBF0DF), Color(0xFFB96E12)),
    (Color(0xFFF0EBF8), Color(0xFF6A4FA3)),
    (Color(0xFFFAE9E6), Color(0xFFC03A2B)),
  ];
}

/// Métricas de la bottom navbar flotante ([TwBottomNavBar]).
///
/// El panel es un vidrio de 68 dp (blur sigma 18, como las cabeceras
/// colapsables) con doble sombra. Aquí solo viven las medidas que otras
/// pantallas necesitan para reservar espacio bajo su contenido.
abstract final class GlassNavTokens {
  static const height = 68.0;
  static const radius = 26.0;

  static const horizontalMargin = 14.0;

  /// Aire extra bajo el panel, **además** del home indicator / safe area.
  static const bottomMargin = 8.0;

  /// Anillo alrededor del panel que absorbe los taps. Con `extendBody` el
  /// contenido pasa por debajo de la navbar; sin esta zona muerta, un dedo
  /// que apunta al borde del panel y falla activa la fila que quedó detrás.
  static const deadZone = 10.0;

  /// Holgura extra en PWA (iPhone): separa la navbar de la barra nativa.
  static const webBottomExtra = 14.0;

  static const iconSize = 24.0;
  static const labelSize = 12.0;

  static const transitionDuration = Duration(milliseconds: 180);
  static const transitionCurve = Curves.easeOutCubic;

  /// Panel + margen de flotación, sin safe area ni holgura web.
  static const occupiedHeight = height + bottomMargin;

  static double webBottomGap() => kIsWeb ? webBottomExtra : 0;

  /// Panel + márgenes de flotación (incluye holgura web).
  static double occupiedHeightOf() => occupiedHeight + webBottomGap();

  /// Espacio al final del contenido para que no quede bajo la barra flotante
  /// ni bajo su zona muerta.
  static double contentBottomInset(BuildContext context) =>
      occupiedHeightOf() +
      deadZone +
      MediaQuery.viewPaddingOf(context).bottom +
      AppSpacing.xl;

  static double floatingBottomPadding(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).bottom + bottomMargin + webBottomGap();

  static Color activeColor(Brightness brightness) =>
      brightness == Brightness.dark ? AppColors.accent : AppColors.primary;

  static Color inactiveColor(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color.fromRGBO(255, 255, 255, 0.90)
      : AppColors.ink;
}

class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 28.0;

  static const screenH = 20.0;
  static const screen = EdgeInsets.symmetric(horizontal: screenH);
  static const contentMax = 760.0;
  static const field = SizedBox(height: 14);
  static const sectionGap = 22.0;
  static const cardGap = 10.0;

  /// Altura visual del panel de vidrio de la tab bar (sin márgenes ni safe area).
  static const shellTabBarHeight = GlassNavTokens.height;

  /// Holgura inferior del FAB en pantallas dentro del shell anidado.
  /// El Scaffold interno no ve el [bottomNavigationBar] del padre.
  static const shellFabBottom = GlassNavTokens.occupiedHeight + sm;

  static double shellFabBottomOf() => GlassNavTokens.occupiedHeightOf() + sm;
}

class AppRadius {
  AppRadius._();

  static const sm = 10.0;
  static const md = 12.0;
  static const tile = 13.0;
  static const input = 14.0;
  static const lg = 16.0;
  static const fab = 18.0;
  static const header = 28.0;
  static const pill = 99.0;
}

class AppMotion {
  AppMotion._();

  static const ease = Cubic(0.2, 0.8, 0.2, 1);
  static const screenIn = Duration(milliseconds: 350);
  static const pushIn = Duration(milliseconds: 320);
  static const cardIn = Duration(milliseconds: 400);
  static const press = Duration(milliseconds: 180);
  static const stagger = Duration(milliseconds: 40);
  static const toggle = Duration(milliseconds: 250);
  static const toast = Duration(milliseconds: 2300);

  static bool reduceMotion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);
}

class AppTheme {
  AppTheme._();

  static OutlineInputBorder _twFieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: TwRadii.field,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static ThemeData get light {
    final colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.tintNavy,
      onPrimaryContainer: AppColors.primaryDeep,
      secondary: AppColors.primaryLight,
      onSecondary: Colors.white,
      tertiary: AppColors.accent,
      onTertiary: AppColors.primaryDeep,
      tertiaryContainer: AppColors.tintLime,
      onTertiaryContainer: AppColors.primaryDeep,
      error: AppColors.danger,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.divider,
    );

    final baseText = GoogleFonts.plusJakartaSansTextTheme();
    final textTheme = baseText.copyWith(
      displaySmall: baseText.displaySmall?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: AppColors.ink,
      ),
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        height: 1.3,
        letterSpacing: -0.3,
        color: AppColors.ink,
      ),
      headlineSmall: baseText.headlineSmall?.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        height: 1.28,
        letterSpacing: -0.4,
        color: AppColors.ink,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.35,
        color: AppColors.ink,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.35,
        letterSpacing: -0.2,
        color: AppColors.ink,
      ),
      titleSmall: baseText.titleSmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
      ),
      bodyMedium: baseText.bodyMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
      bodySmall: baseText.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      labelLarge: baseText.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
      labelMedium: baseText.labelMedium?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: AppColors.textTertiary,
      ),
      labelSmall: baseText.labelSmall?.copyWith(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.border,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
      // Mismo campo que `TwTextField`: relleno `fieldBg`, borde `fieldBorder`
      // y radio 12, para que los formularios Material y los del rediseño no se
      // vean como dos sistemas distintos.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TwColors.fieldBg,
        hintStyle: TwText.input.copyWith(color: TwColors.muted),
        labelStyle: TwText.input.copyWith(color: TwColors.secondary),
        border: _twFieldBorder(TwColors.fieldBorder),
        enabledBorder: _twFieldBorder(TwColors.fieldBorder),
        disabledBorder: _twFieldBorder(TwColors.fieldBorder),
        focusedBorder: _twFieldBorder(TwColors.fieldBorder),
        errorBorder: _twFieldBorder(TwColors.danger),
        focusedErrorBorder: _twFieldBorder(TwColors.danger, width: 1.5),
        errorStyle: TwText.errorText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.tintNavy,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        labelStyle: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryDeep,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: const ListTileThemeData(iconColor: AppColors.primary),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: GlassNavTokens.labelSize,
            fontWeight: active ? FontWeight.w500 : FontWeight.w400,
            height: 1.1,
            color: active ? AppColors.primary : AppColors.ink,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            color: active ? AppColors.primary : AppColors.ink,
            size: GlassNavTokens.iconSize,
          );
        }),
      ),
    );
  }
}
