import 'package:cerebro_mobile/shared/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppColors', () {
    test('exposes the expected named colors', () {
      expect(AppColors.accentPrimary, isA<Color>()); // violet
      expect(AppColors.accentSecondary, isA<Color>()); // teal
      expect(AppColors.accentLocked, isA<Color>()); // amber
      expect(AppColors.bgBase, isA<Color>()); // background
      expect(AppColors.textPrimary, isA<Color>()); // text
    });

    test('amber (locked) hex is unique among all defined tokens', () {
      final amber = AppColors.accentLocked.toARGB32();

      final allOtherTokens = <String, Color>{
        'black': AppColors.black,
        'surface': AppColors.surface,
        'surfaceHover': AppColors.surfaceHover,
        'surfaceRaised': AppColors.surfaceRaised,
        'violet': AppColors.violet,
        'violetHover': AppColors.violetHover,
        'violetActive': AppColors.violetActive,
        'teal': AppColors.teal,
        'tealHover': AppColors.tealHover,
        'tealActive': AppColors.tealActive,
        'amberHover': AppColors.amberHover,
        'amberActive': AppColors.amberActive,
        'red': AppColors.red,
        'redHover': AppColors.redHover,
        'redActive': AppColors.redActive,
        'green': AppColors.green,
        'greenHover': AppColors.greenHover,
        'greenActive': AppColors.greenActive,
        'white': AppColors.white,
        'gray': AppColors.gray,
        'grayDim': AppColors.grayDim,
        'borderSubtle': AppColors.borderSubtle,
        'borderDefault': AppColors.borderDefault,
        'borderStrong': AppColors.borderStrong,
        'textOnAccent': AppColors.textOnAccent,
        'danger': AppColors.danger,
        'dangerHover': AppColors.dangerHover,
        'dangerActive': AppColors.dangerActive,
      };

      for (final entry in allOtherTokens.entries) {
        expect(
          entry.value.toARGB32(),
          isNot(equals(amber)),
          reason:
              '${entry.key} resolves to the same hex as amber (locked) — '
              "amber's meaning as sealed-tier-exclusive would be diluted.",
        );
      }
    });
  });
}
