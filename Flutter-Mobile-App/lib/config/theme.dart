import 'package:flutter/material.dart';

/// Pulled directly from the original app's src/lib/theme.ts, which itself
/// was pulled from agricast-web's --color-brand-* CSS variables — so this
/// matches the real brand, not a Material default.
class AppColors {
  static const brandGreen = Color(0xFF159947);
  static const brandGreenDark = Color(0xFF12813C);
  static const brandGreenLight = Color(0xFFE7F5EC);
  static const accent = brandGreen;
  static const border = Color(0xFFEAEAEA);
  static const text = Color(0xFF111111);
  static const muted = Color(0xFF6B7280);
  static const danger = Color(0xFFC0392B);
  static const white = Color(0xFFFFFFFF);
  static const background = Color(0xFFFAFAF8);
}

/// Original used Plus Jakarta Sans for headings and Manrope for body text.
/// Both are bundled locally under assets/fonts/ (see pubspec.yaml) instead
/// of fetched at runtime — no network call needed just to render text, and
/// it avoids macOS App Sandbox network-entitlement issues on the desktop
/// target entirely.
class AppFonts {
  static TextStyle heading({double size = 26, Color color = AppColors.brandGreenDark, FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, color: color, fontWeight: weight);

  static TextStyle headingSemibold({double size = 17, Color color = AppColors.text}) =>
      TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, color: color, fontWeight: FontWeight.w600);

  static TextStyle body({double size = 15, Color color = AppColors.text}) =>
      TextStyle(fontFamily: 'Manrope', fontSize: size, color: color, fontWeight: FontWeight.w400);

  static TextStyle bodyMedium({double size = 14, Color color = AppColors.text}) =>
      TextStyle(fontFamily: 'Manrope', fontSize: size, color: color, fontWeight: FontWeight.w500);

  static TextStyle bodySemibold({double size = 14, Color color = AppColors.text}) =>
      TextStyle(fontFamily: 'Manrope', fontSize: size, color: color, fontWeight: FontWeight.w600);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Manrope',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brandGreen,
      primary: AppColors.brandGreen,
    ),
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      titleTextStyle: AppFonts.headingSemibold(size: 18),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brandGreen,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: AppFonts.headingSemibold(size: 16, color: AppColors.white),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brandGreenDark,
        side: const BorderSide(color: AppColors.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: AppFonts.headingSemibold(size: 16, color: AppColors.brandGreenDark),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      labelStyle: AppFonts.bodyMedium(color: AppColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: AppColors.brandGreen, width: 1.5),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.brandGreen,
      foregroundColor: AppColors.white,
    ),
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
  );
}
