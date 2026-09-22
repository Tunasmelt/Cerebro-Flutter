import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_typography.dart';

/// Assembles the token files into a Flutter [ThemeData]. Dark-only —
/// web is dark-only (`color-scheme: dark` in globals.css), no light
/// theme to port.
abstract final class AppTheme {
  static ThemeData get dark {
    final colorScheme = ColorScheme.dark(
      surface: AppColors.bgBase,
      onSurface: AppColors.textPrimary,
      primary: AppColors.accentPrimary,
      onPrimary: AppColors.textOnAccent,
      secondary: AppColors.accentSecondary,
      onSecondary: AppColors.textOnAccent,
      error: AppColors.danger,
      onError: AppColors.textOnAccent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bgBase,
      fontFamily: AppTypography.fontFamilyUi,
      textTheme: const TextTheme(
        bodySmall: AppTypography.sm,
        bodyMedium: AppTypography.base,
        bodyLarge: AppTypography.md,
        titleMedium: AppTypography.lg,
        titleLarge: AppTypography.xl,
        headlineSmall: AppTypography.xxl,
        headlineMedium: AppTypography.xxxl,
        headlineLarge: AppTypography.xxxxl,
      ),
      cardColor: AppColors.bgElevated,
      dividerColor: AppColors.borderDefault,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentPrimary,
          foregroundColor: AppColors.textOnAccent,
          disabledBackgroundColor: AppColors.grayDim,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.mdRadius,
          ),
          minimumSize: const Size(64, 44), // touch target minimum height
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgElevated,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.borderDefault),
        ),
      ),
    );
  }
}
