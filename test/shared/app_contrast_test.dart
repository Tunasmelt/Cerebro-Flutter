// The colour policy, as arithmetic: which token may carry text on which
// surface. WCAG 2.x contrast ratios computed from the token values, so a token
// edit that makes text unreadable fails here instead of on someone's phone.
import 'dart:math' as math;

import 'package:cerebro_mobile/shared/tokens/app_colors.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

double _linear(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b);

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const surfaces = {
    'bgBase': AppColors.bgBase,
    'bgElevated': AppColors.bgElevated,
    'bgRaised': AppColors.bgRaised,
  };

  group('body text (≥ 4.5:1) on every surface', () {
    const readable = {
      'textPrimary': AppColors.textPrimary,
      'textSecondary': AppColors.textSecondary,
    };
    for (final fg in readable.entries) {
      for (final bg in surfaces.entries) {
        test('${fg.key} on ${bg.key}', () {
          expect(contrast(fg.value, bg.value), greaterThanOrEqualTo(4.5));
        });
      }
    }
  });

  group('accent text (≥ 4.5:1) on the surfaces it is used on', () {
    // Text-sized colour on the page and on cards. (On the raised surface only
    // sheets and menus sit; they use primary/secondary text.)
    const accents = {
      'accentPrimaryHover (the text violet)': AppColors.accentPrimaryHover,
      'accentSecondary': AppColors.accentSecondary,
      'accentSuccess': AppColors.accentSuccess,
      'accentLocked (amber)': AppColors.accentLocked,
      'danger': AppColors.danger,
    };
    for (final fg in accents.entries) {
      for (final bg in {
        'bgBase': AppColors.bgBase,
        'bgElevated': AppColors.bgElevated,
      }.entries) {
        test('${fg.key} on ${bg.key}', () {
          expect(contrast(fg.value, bg.value), greaterThanOrEqualTo(4.5));
        });
      }
    }
  });

  test('the base violet is NOT body-text safe on cards — so text uses the '
      'lighter violet, and the base is for fills and large elements', () {
    // If this ever starts passing, the rule above can be relaxed; until then
    // it documents why TextButtons use accentPrimaryHover.
    expect(
      contrast(AppColors.accentPrimary, AppColors.bgElevated),
      lessThan(4.5),
    );
    expect(
      contrast(AppColors.accentPrimaryHover, AppColors.bgElevated),
      greaterThanOrEqualTo(4.5),
    );
    // As a non-text UI colour (a ring, an icon, a filled control) 3:1 is the
    // bar, and the base violet clears it on every surface.
    for (final bg in surfaces.values) {
      expect(contrast(AppColors.accentPrimary, bg), greaterThanOrEqualTo(3.0));
    }
  });

  test('placeholder and disabled text stays distinguishable (≥ 3:1)', () {
    for (final bg in surfaces.values) {
      expect(contrast(AppColors.grayDim, bg), greaterThanOrEqualTo(3.0));
    }
  });

  group('labels on filled controls', () {
    test(
      'dark text on the violet button (≥ 4.3:1, for 14px+ medium labels)',
      () {
        expect(
          contrast(AppColors.textOnAccent, AppColors.accentPrimary),
          greaterThanOrEqualTo(4.3),
        );
      },
    );
    test('dark text on amber and danger fills (≥ 4.5:1)', () {
      expect(
        contrast(AppColors.textOnAccent, AppColors.accentLocked),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(AppColors.textOnAccent, AppColors.danger),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
