import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// Assembles the token files into a Flutter [ThemeData]. Dark-only —
/// web is dark-only (`color-scheme: dark` in globals.css), no light
/// theme to port.
///
/// Every Material component the app uses is themed here, so a screen that
/// reaches for a stock `Dialog`, `Chip` or `ListTile` already looks like
/// Cerebro instead of falling back to Material defaults (a light selection
/// toolbar, an unstyled outline button...).
abstract final class AppTheme {
  static const _border = BorderSide(color: AppColors.borderDefault);
  static const _minTarget = Size(64, AppSpacing.minTouchTarget);

  static TextStyle _display(TextStyle base, FontWeight weight) => base.copyWith(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontWeight: weight,
  );

  static ThemeData get dark {
    final colorScheme = ColorScheme.dark(
      surface: AppColors.bgBase,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceTint: Colors.transparent, // no M3 elevation tint
      surfaceContainerLowest: AppColors.bgBase,
      surfaceContainerLow: AppColors.bgBase,
      surfaceContainer: AppColors.bgElevated,
      surfaceContainerHigh: AppColors.bgRaised,
      surfaceContainerHighest: AppColors.bgRaised,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.borderSubtle,
      primary: AppColors.accentPrimary,
      onPrimary: AppColors.textOnAccent,
      primaryContainer: AppColors.accentPrimarySubtle,
      onPrimaryContainer: AppColors.textPrimary,
      secondary: AppColors.accentSecondary,
      onSecondary: AppColors.textOnAccent,
      secondaryContainer: AppColors.accentSecondarySubtle,
      onSecondaryContainer: AppColors.textPrimary,
      error: AppColors.danger,
      onError: AppColors.textOnAccent,
      inverseSurface: AppColors.textPrimary,
      onInverseSurface: AppColors.bgBase,
    );

    final textTheme =
        TextTheme(
          // Display family for titles; UI family for everything else.
          headlineLarge: _display(
            AppTypography.xxxxl,
            AppTypography.weightBold,
          ),
          headlineMedium: _display(
            AppTypography.xxxl,
            AppTypography.weightBold,
          ),
          headlineSmall: _display(
            AppTypography.xxl,
            AppTypography.weightSemibold,
          ),
          titleLarge: _display(AppTypography.xl, AppTypography.weightSemibold),
          titleMedium: AppTypography.lg.copyWith(
            fontWeight: AppTypography.weightMedium,
          ),
          titleSmall: AppTypography.md.copyWith(
            fontWeight: AppTypography.weightMedium,
          ),
          bodyLarge: AppTypography.md,
          bodyMedium: AppTypography.base,
          bodySmall: AppTypography.sm,
          labelLarge: AppTypography.base.copyWith(
            fontWeight: AppTypography.weightMedium,
          ),
          labelMedium: AppTypography.sm.copyWith(
            fontWeight: AppTypography.weightMedium,
          ),
          labelSmall: AppTypography.xs.copyWith(
            fontWeight: AppTypography.weightMedium,
          ),
        ).apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        );

    final cardShape = RoundedRectangleBorder(
      borderRadius: AppRadius.lgRadius,
      side: const BorderSide(color: AppColors.borderSubtle),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bgBase,
      fontFamily: AppTypography.fontFamilyUi,
      textTheme: textTheme,
      cardColor: AppColors.bgElevated,
      dividerColor: AppColors.borderDefault,
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgBase,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: _display(
          AppTypography.xl,
          AppTypography.weightSemibold,
        ).copyWith(color: AppColors.textPrimary),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: cardShape,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceHover,
        selectedColor: AppColors.accentPrimarySubtle,
        disabledColor: AppColors.surfaceHover,
        side: _border,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
        labelStyle: AppTypography.sm.copyWith(color: AppColors.textPrimary),
        secondaryLabelStyle: AppTypography.sm.copyWith(
          color: AppColors.textPrimary,
        ),
        checkmarkColor: AppColors.accentPrimaryHover,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s1),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgRadius,
          side: const BorderSide(color: AppColors.borderDefault),
        ),
        titleTextStyle: AppTypography.lg.copyWith(
          color: AppColors.textPrimary,
          fontWeight: AppTypography.weightSemibold,
        ),
        contentTextStyle: AppTypography.base.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bgElevated,
        modalBackgroundColor: AppColors.bgElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bgRaised,
        contentTextStyle: AppTypography.sm.copyWith(
          color: AppColors.textPrimary,
        ),
        actionTextColor: AppColors.accentPrimaryHover,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        titleTextStyle: AppTypography.base.copyWith(
          color: AppColors.textPrimary,
        ),
        subtitleTextStyle: AppTypography.sm.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.bgRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdRadius,
          side: _border,
        ),
        textStyle: AppTypography.sm.copyWith(color: AppColors.textPrimary),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accentPrimary,
        linearTrackColor: AppColors.surfaceHover,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.bgRaised,
          borderRadius: AppRadius.smRadius,
          border: Border.all(color: AppColors.borderDefault),
        ),
        textStyle: AppTypography.xs.copyWith(color: AppColors.textPrimary),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.accentPrimary,
        selectionColor: AppColors.accentPrimary.withValues(alpha: 0.3),
        selectionHandleColor: AppColors.accentPrimary,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentPrimary,
        foregroundColor: AppColors.textOnAccent,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.accentPrimary
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.textOnAccent),
        side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.textOnAccent
              : AppColors.grayDim,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.accentPrimary
              : AppColors.surfaceHover,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(
          AppColors.borderDefault,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(64, AppSpacing.minTouchTarget),
          ),
          textStyle: WidgetStatePropertyAll(AppTypography.sm),
          side: const WidgetStatePropertyAll(_border),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? AppColors.accentPrimarySubtle
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? AppColors.textPrimary
                : AppColors.textSecondary,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentPrimary,
          foregroundColor: AppColors.textOnAccent,
          disabledBackgroundColor: AppColors.grayDim,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
          minimumSize: _minTarget, // touch target minimum height
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentPrimary,
          foregroundColor: AppColors.textOnAccent,
          disabledBackgroundColor: AppColors.surfaceRaised,
          disabledForegroundColor: AppColors.textDisabled,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
          minimumSize: _minTarget,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderStrong),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
          minimumSize: _minTarget,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          // The lighter violet: the base violet is borderline on the dark
          // surfaces at body sizes.
          foregroundColor: AppColors.accentPrimaryHover,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
          minimumSize: const Size(AppSpacing.minTouchTarget, 44),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          minimumSize: const Size.square(AppSpacing.minTouchTarget),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgElevated,
        hintStyle: AppTypography.base.copyWith(color: AppColors.textDisabled),
        labelStyle: AppTypography.base.copyWith(color: AppColors.textSecondary),
        floatingLabelStyle: AppTypography.sm.copyWith(
          color: AppColors.textSecondary,
        ),
        errorStyle: AppTypography.xs.copyWith(color: AppColors.danger),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s3,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(
            color: AppColors.accentPrimary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
    );
  }
}
