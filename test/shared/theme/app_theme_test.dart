// The theme layer: every component the app uses is themed, so a stock widget
// already looks like Cerebro.
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:cerebro_mobile/shared/tokens/app_colors.dart';
import 'package:cerebro_mobile/shared/tokens/app_spacing.dart';
import 'package:cerebro_mobile/shared/tokens/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final theme = AppTheme.dark;

  group('colour scheme', () {
    test('no Material 3 surface tint', () {
      expect(theme.colorScheme.surfaceTint, Colors.transparent);
    });

    test('surfaces layer bgBase -> bgElevated -> bgRaised', () {
      final s = theme.colorScheme;
      expect(s.surface, AppColors.bgBase);
      expect(s.surfaceContainer, AppColors.bgElevated);
      expect(s.surfaceContainerHigh, AppColors.bgRaised);
    });

    test('outline colours are the border tokens, not M3-derived greys', () {
      expect(theme.colorScheme.outline, AppColors.borderStrong);
      expect(theme.colorScheme.outlineVariant, AppColors.borderSubtle);
    });
  });

  group('type', () {
    test('titles use the display face, body text the UI face', () {
      expect(
        theme.textTheme.headlineMedium!.fontFamily,
        AppTypography.fontFamilyDisplay,
      );
      expect(
        theme.textTheme.titleLarge!.fontFamily,
        AppTypography.fontFamilyDisplay,
      );
      expect(
        theme.textTheme.bodyMedium!.fontFamily,
        isNot(AppTypography.fontFamilyDisplay),
      );
    });

    test('text colours are set, not left to Material defaults', () {
      expect(theme.textTheme.bodyMedium!.color, AppColors.textPrimary);
      expect(theme.textTheme.headlineLarge!.color, AppColors.textPrimary);
    });

    test('label styles exist for buttons and chips', () {
      expect(theme.textTheme.labelLarge, isNotNull);
      expect(theme.textTheme.labelSmall, isNotNull);
    });
  });

  group('components', () {
    test('dialogs, sheets, menus and snackbars use the surface tokens', () {
      expect(theme.dialogTheme.backgroundColor, AppColors.bgElevated);
      expect(theme.bottomSheetTheme.backgroundColor, AppColors.bgElevated);
      expect(theme.popupMenuTheme.color, AppColors.bgRaised);
      expect(theme.snackBarTheme.backgroundColor, AppColors.bgRaised);
    });

    test('app bars sit flat on the page', () {
      expect(theme.appBarTheme.backgroundColor, AppColors.bgBase);
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
      expect(
        theme.appBarTheme.titleTextStyle!.fontFamily,
        AppTypography.fontFamilyDisplay,
      );
    });

    test('text selection is violet (not the light Android toolbar)', () {
      expect(theme.textSelectionTheme.cursorColor, AppColors.accentPrimary);
      expect(
        theme.textSelectionTheme.selectionHandleColor,
        AppColors.accentPrimary,
      );
    });

    test('inputs show focus and error states', () {
      final d = theme.inputDecorationTheme;
      expect(
        (d.focusedBorder! as OutlineInputBorder).borderSide.color,
        AppColors.accentPrimary,
      );
      expect(
        (d.errorBorder! as OutlineInputBorder).borderSide.color,
        AppColors.danger,
      );
    });

    test('chips and cards use the border tokens', () {
      expect(theme.chipTheme.side!.color, AppColors.borderDefault);
      expect(theme.cardTheme.elevation, 0);
    });

    test('text buttons use the readable (lighter) violet', () {
      final fg = theme.textButtonTheme.style!.foregroundColor!.resolve({});
      expect(fg, AppColors.accentPrimaryHover);
    });
  });

  group('every button is at least a touch target tall', () {
    Size min(ButtonStyle? s) => s!.minimumSize!.resolve({})!;

    test('filled, elevated, outlined, text', () {
      for (final style in [
        theme.filledButtonTheme.style,
        theme.elevatedButtonTheme.style,
        theme.outlinedButtonTheme.style,
        theme.textButtonTheme.style,
      ]) {
        expect(
          min(style).height,
          greaterThanOrEqualTo(AppSpacing.minTouchTarget),
        );
      }
    });

    test('icon buttons and segmented buttons', () {
      expect(
        min(theme.iconButtonTheme.style).shortestSide,
        greaterThanOrEqualTo(AppSpacing.minTouchTarget),
      );
      expect(
        min(theme.segmentedButtonTheme.style).height,
        greaterThanOrEqualTo(AppSpacing.minTouchTarget),
      );
    });
  });

  group('rendered', () {
    testWidgets(
      'a stock AlertDialog takes the theme, with no defaults leaking',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const AlertDialog(
                    title: Text('Title'),
                    content: Text('Body'),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final material = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(material.color, AppColors.bgElevated);
        // Plain Text takes its colour from the nearest DefaultTextStyle, which
        // the dialog theme sets.
        expect(
          DefaultTextStyle.of(tester.element(find.text('Body'))).style.color,
          AppColors.textSecondary,
        );
      },
    );
  });
}
