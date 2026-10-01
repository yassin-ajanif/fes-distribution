import 'package:flutter/material.dart';

class AppColors {
  static const brand = Color(0xFF2E8B3A);
  static const brandSoft = Color(0xFFEAF8EC);
  static const accent = Color(0xFF56C42B);
  static const surface = Color(0xFFF5FAF5);
  static const card = Color(0xFFFFFFFF);
  static const muted = Color(0xFF5A6B5E);
  static const line = Color(0xFFCDE5CF);
  static const danger = Color(0xFFC0392B);
  static const dangerSoft = Color(0xFFFBE9E7);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    primary: AppColors.brand,
    surface: AppColors.surface,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.surface,
    fontFamily: 'Segoe UI',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.card,
      indicatorColor: AppColors.brandSoft,
      selectedIconTheme: const IconThemeData(color: AppColors.brand),
      selectedLabelTextStyle: const TextStyle(color: AppColors.brand),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.line, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.line, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
    ),
  );
}
