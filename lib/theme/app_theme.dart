import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens pulled directly from the Stitch export's DESIGN.md
/// ("Hamqadam" design system). Keep this file as the single source of
/// truth for colors / spacing / radii so every screen stays consistent.
class AppColors {
  AppColors._();

  static const surface = Color(0xFFF6FAF8);
  static const surfaceDim = Color(0xFFD6DBD9);
  static const surfaceBright = Color(0xFFF6FAF8);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF0F5F2);
  static const surfaceContainer = Color(0xFFEAEFEC);
  static const surfaceContainerHigh = Color(0xFFE4E9E7);
  static const surfaceContainerHighest = Color(0xFFDFE4E1);

  static const onSurface = Color(0xFF171D1B);
  static const onSurfaceVariant = Color(0xFF3D4946);
  static const inverseSurface = Color(0xFF2C3130);
  static const inverseOnSurface = Color(0xFFEDF2EF);

  static const outline = Color(0xFF6D7A77);
  static const outlineVariant = Color(0xFFBCC9C5);

  static const primary = Color(0xFF00685D);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF008376);
  static const onPrimaryContainer = Color(0xFFF4FFFB);
  static const inversePrimary = Color(0xFF70D8C8);

  static const secondary = Color(0xFF006A62);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFF81F3E5);
  static const onSecondaryContainer = Color(0xFF006F66);

  static const tertiary = Color(0xFF91462C);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFFB05E41);
  static const onTertiaryContainer = Color(0xFFFFFBFF);

  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  static const background = Color(0xFFF6FAF8);
  static const onBackground = Color(0xFF171D1B);
  static const surfaceVariant = Color(0xFFDFE4E1);

  // Extra flat brand accents used ad-hoc in the mockups
  static const brandTeal = Color(0xFF00897B); // primary buttons in HTML
  static const brandTealDark = Color(0xFF00796B);
  static const statusAmberBg = Color(0xFFFFF8E1);
  static const statusAmberFg = Color(0xFFF57F17);
  static const statusGreenBg = Color(0xFFE8F5E9);
  static const statusGreenFg = Color(0xFF2E7D32);
  static const onlineDot = Color(0xFF10B981);
  static const starGold = Color(0xFFF59E0B);
}

class AppSpacing {
  AppSpacing._();
  static const base = 4.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const marginMobile = 16.0;
}

class AppRadius {
  AppRadius._();
  static const sm = 4.0;
  static const dflt = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const full = 999.0;
}

class AppShadows {
  AppShadows._();
  static const soft = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const active = [
    BoxShadow(color: Color(0x14008973), blurRadius: 16, offset: Offset(0, 8)),
  ];
}

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _base => GoogleFonts.beVietnamPro(color: AppColors.onSurface);

  static TextStyle headlineLg = _base.copyWith(fontSize: 32, fontWeight: FontWeight.w700, height: 40 / 32, letterSpacing: -0.02 * 32);
  static TextStyle headlineLgMobile = _base.copyWith(fontSize: 24, fontWeight: FontWeight.w700, height: 32 / 24, letterSpacing: -0.01 * 24);
  static TextStyle headlineMd = _base.copyWith(fontSize: 20, fontWeight: FontWeight.w600, height: 28 / 20);
  static TextStyle bodyLg = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 24 / 16);
  static TextStyle bodyMd = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400, height: 20 / 14);
  static TextStyle labelLg = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w600, height: 20 / 14, letterSpacing: 0.1);
  static TextStyle labelSm = _base.copyWith(fontSize: 12, fontWeight: FontWeight.w500, height: 16 / 12, letterSpacing: 0.4);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.secondary,
        error: AppColors.error,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: GoogleFonts.beVietnamPro().fontFamily,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.primary),
        titleTextStyle: AppTextStyles.headlineMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandTeal,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(56),
          textStyle: AppTextStyles.labelLg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(48),
          textStyle: AppTextStyles.labelLg,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle: AppTextStyles.bodyLg.copyWith(color: AppColors.onSurfaceVariant.withOpacity(0.7)),
      ),
      dividerTheme: DividerThemeData(color: AppColors.surfaceVariant.withOpacity(0.5), thickness: 1),
    );
  }

  /// Dark counterpart of [light]. Applied app-wide via `MaterialApp.darkTheme`
  /// + `themeMode`, driven by `AppSettingsController` (see the Dark Mode
  /// switch on the seeker Profile screen). Anything that reads colors from
  /// `Theme.of(context)` — scaffold backgrounds, app bars, buttons, inputs,
  /// dividers, dialogs, switches, snackbars — repaints automatically when
  /// this is switched to. Screens that instead paint with the hardcoded
  /// `AppColors.*` constants (most of the card/tile backgrounds across the
  /// app) keep their existing light appearance either way; only the
  /// theme-driven chrome adapts.
  static ThemeData get dark {
    const darkBackground = Color(0xFF10201C);
    const darkSurface = Color(0xFF17251F);
    const darkSurfaceHigh = Color(0xFF1F2E28);
    const darkOnSurface = Color(0xFFE2E8E5);
    const darkOnSurfaceVariant = Color(0xFFAAB8B3);

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.inversePrimary,
        onPrimary: const Color(0xFF00382F),
        secondary: AppColors.secondaryContainer,
        error: const Color(0xFFFFB4AB),
        surface: darkSurface,
        onSurface: darkOnSurface,
      ),
      scaffoldBackgroundColor: darkBackground,
      fontFamily: GoogleFonts.beVietnamPro().fontFamily,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.inversePrimary),
        titleTextStyle: AppTextStyles.headlineMd.copyWith(color: AppColors.inversePrimary, fontWeight: FontWeight.w700),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.inversePrimary,
          foregroundColor: const Color(0xFF00382F),
          minimumSize: const Size.fromHeight(56),
          textStyle: AppTextStyles.labelLg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inversePrimary,
          minimumSize: const Size.fromHeight(48),
          textStyle: AppTextStyles.labelLg,
          side: const BorderSide(color: AppColors.inversePrimary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.inversePrimary, width: 2),
        ),
        hintStyle: AppTextStyles.bodyLg.copyWith(color: darkOnSurfaceVariant),
      ),
      dividerTheme: DividerThemeData(color: Colors.white.withOpacity(0.08), thickness: 1),
      cardColor: darkSurface,
      dialogTheme: DialogThemeData(backgroundColor: darkSurface),
      snackBarTheme: SnackBarThemeData(backgroundColor: darkSurfaceHigh, contentTextStyle: AppTextStyles.bodyMd.copyWith(color: darkOnSurface)),
    );
  }
}
