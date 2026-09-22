import 'package:flutter/material.dart';

/// Ported 1:1 from the web repo's actual source values at
/// `Cerebro 2.0/apps/web/src/app/styles/tokens/colors.css`, per
/// AGENTS.md's source-of-truth hierarchy (web repo's actual code, not
/// prose). `ui-design-prompts.md` referenced by `flutter-rules.md` does
/// not exist in either repo — this file was ported from the real CSS
/// tokens instead.
///
/// `locked` (amber) is reserved EXCLUSIVELY for sealed/encryption UI.
/// No other token in this file may resolve to the same hex value —
/// enforced by test/shared/app_colors_test.dart.
abstract final class AppColors {
  // Base palette
  static const black = Color(0xFF080B12);
  static const surface = Color(0xFF0E1320);
  static const surfaceHover = Color(0xFF141B2D);
  static const surfaceRaised = Color(0xFF1A2238);

  static const violet = Color(0xFF7C5AF6);
  static const violetHover = Color(0xFF9277F8);
  static const violetActive = Color(0xFF6946E6);

  static const teal = Color(0xFF22D3EE);
  static const tealHover = Color(0xFF67E8F9);
  static const tealActive = Color(0xFF06B6D4);

  static const amber = Color(0xFFF59E0B);
  static const amberHover = Color(0xFFFBBF24);
  static const amberActive = Color(0xFFD97706);

  static const red = Color(0xFFF43F5E);
  static const redHover = Color(0xFFF87171);
  static const redActive = Color(0xFFDC2626);

  static const green = Color(0xFF10B981);
  static const greenHover = Color(0xFF34D399);
  static const greenActive = Color(0xFF059669);

  static const white = Color(0xFFE8ECF5);
  static const gray = Color(0xFF91A0BD);
  static const grayDim = Color(0xFF6B7A99);

  // Surfaces
  static const bgBase = black;
  static const bgElevated = surface;
  static const bgElevatedHover = surfaceHover;
  static const bgRaised = surfaceRaised;

  // Borders — always low-opacity white, never harsh black lines
  static const borderSubtle = Color(0xFF182136);
  static const borderDefault = Color(0xFF25304A);
  static const borderStrong = Color(0xFF34415F);

  // Text
  static const textPrimary = white;
  static const textSecondary = gray;
  static const textDisabled = grayDim;
  static const textOnAccent = Color(0xFF080B12);

  // Primary accent — violet. Sparingly: active/live states, retrieval
  // pulses, primary CTAs.
  static const accentPrimary = violet;
  static const accentPrimaryHover = violetHover;
  static const accentPrimaryActive = violetActive;
  static const accentPrimarySubtle = Color(0x1F8B5CF6); // rgba(139,92,246,.12)
  static const accentPrimaryBorder = Color(0x668B5CF6); // rgba(139,92,246,.4)

  // Secondary accent — teal. Secondary actions, informational states.
  static const accentSecondary = teal;
  static const accentSecondaryHover = tealHover;
  static const accentSecondaryActive = tealActive;
  static const accentSecondarySubtle = Color(0x1F2DD4BF); // rgba(45,212,191,.12)

  // Success accent — green. "done"/"ready"/"completed" states, distinct
  // from teal's informational/secondary role — don't blur the two.
  static const accentSuccess = green;
  static const accentSuccessHover = greenHover;
  static const accentSuccessActive = greenActive;
  static const accentSuccessSubtle = Color(0x1F10B981); // rgba(16,185,129,.12)

  // Locked accent — amber. Reserved EXCLUSIVELY for
  // encryption/lock-related UI. No exceptions.
  static const accentLocked = amber;
  static const accentLockedHover = amberHover;
  static const accentLockedActive = amberActive;
  static const accentLockedSubtle = Color(0x1FF59E0B); // rgba(245,158,11,.12)

  // Danger — destructive actions only, never reused for lock states.
  static const danger = red;
  static const dangerHover = redHover;
  static const dangerActive = redActive;
  static const dangerSubtle = Color(0x1FEF4444); // rgba(239,68,68,.12)
}
