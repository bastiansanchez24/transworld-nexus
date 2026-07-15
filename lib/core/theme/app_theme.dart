import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tokens de color del rediseño Nexus (HANDOFF §1). Únicos permitidos.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF14507F); // navy-700
  static const primaryDeep = Color(0xFF0C3357); // navy-900
  static const primaryLight = Color(0xFF175E93); // navy-500
  static const ink = Color(0xFF10263D);
  static const textSecondary = Color(0xFF5C6E82);
  static const textTertiary = Color(0xFF8CA0B3);
  static const background = Color(0xFFF2F5F9);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE4EAF1);
  static const tintNavy = Color(0xFFE8F0F8);
  static const success = Color(0xFF178A56);
  static const successTint = Color(0xFFE5F4EC);
  static const warning = Color(0xFFB96E12);
  static const warningTint = Color(0xFFFBF0DF);
  static const danger = Color(0xFFC03A2B);
  static const dangerTint = Color(0xFFFAE9E6);
  static const placeholder = Color(0xFF93A5B8);
  static const chevronMuted = Color(0xFFC6D2DE);
  static const divider = Color(0xFFF0F4F8);
  static const dashedBorder = Color(0xFFB9C8D6);
  static const toggleOff = Color(0xFFD4DDE6);
  static const toastCheck = Color(0xFF5BD69B);

  /// Alias de compatibilidad con pantallas legacy.
  static const primaryDark = primaryDeep;
  static const error = danger;
  static const accent = success;
  static const surfaceMuted = tintNavy;

  static const headerGradient = LinearGradient(
    colors: [primaryDeep, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const shadowRest = [
    BoxShadow(
      color: Color(0x0D0D2A4A),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  static const shadowLifted = [
    BoxShadow(
      color: Color(0x1A0D2A4A),
      offset: Offset(0, 6),
      blurRadius: 18,
    ),
  ];

  static const shadowFab = [
    BoxShadow(
      color: Color(0x660C3357),
      offset: Offset(0, 10),
      blurRadius: 24,
    ),
  ];

  static const shadowHero = [
    BoxShadow(
      color: Color(0x47041426),
      offset: Offset(0, 10),
      blurRadius: 26,
    ),
  ];

  static const shadowToast = [
    BoxShadow(
      color: Color(0x59041426),
      offset: Offset(0, 12),
      blurRadius: 28,
    ),
  ];

  static const avatarPairs = <(Color, Color)>[
    (Color(0xFFE8F0F8), Color(0xFF14507F)),
    (Color(0xFFE5F4EC), Color(0xFF178A56)),
    (Color(0xFFFBF0DF), Color(0xFFB96E12)),
    (Color(0xFFF0EBF8), Color(0xFF6A4FA3)),
    (Color(0xFFFAE9E6), Color(0xFFC03A2B)),
  ];
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
  static const field = SizedBox(height: 14);
  static const sectionGap = 22.0;
  static const cardGap = 10.0;

  /// Altura del contenido de la tab bar del shell (sin safe area).
  static const shellTabBarHeight = 64.0;

  /// Holgura inferior del FAB en pantallas dentro del shell anidado.
  /// El Scaffold interno no ve el [bottomNavigationBar] del padre.
  static const shellFabBottom = shellTabBarHeight + sm;
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

  static ThemeData get light {
    final colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.tintNavy,
      onPrimaryContainer: AppColors.primaryDeep,
      secondary: AppColors.primaryLight,
      onSecondary: Colors.white,
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
        letterSpacing: -0.2,
        color: AppColors.ink,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: AppColors.ink,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.35,
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
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(
          color: AppColors.placeholder,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
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
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.primary,
      ),
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
        backgroundColor: AppColors.surface.withValues(alpha: 0.94),
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 10.5,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? AppColors.primaryDeep : AppColors.textTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            color: active ? AppColors.primary : AppColors.textTertiary,
            size: 24,
          );
        }),
      ),
    );
  }
}
