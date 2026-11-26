import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xff1677e8);
  static const dark = Color(0xff103f87);
  static const light = Color(0xffeaf5ff);
  static const background = Color(0xfff5faff);
  static const text = Color(0xff102a56);
  static const muted = Color(0xff64748b);
}

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
    ),
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    ),
  );
}
