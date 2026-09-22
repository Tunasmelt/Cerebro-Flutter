import 'package:flutter/material.dart';

/// Ported from `Cerebro 2.0/apps/web/src/app/styles/tokens/typography.css`.
/// Font families are bundled as variable-font assets (see `pubspec.yaml`
/// → `flutter.fonts` and `assets/fonts/`), sourced from the same Google
/// Fonts families web declares via `next/font/google` in
/// `apps/web/src/app/layout.tsx` (DM Sans, Outfit, JetBrains Mono).
///
/// `mono` is for numeric values (token counts, byte sizes, hashes) —
/// same "monospace for numbers" rule as web, per flutter-rules.md.
abstract final class AppTypography {
  static const String fontFamilyUi = 'DM Sans';
  static const String fontFamilyDisplay = 'Outfit';
  static const String fontFamilyMono = 'JetBrains Mono';

  static const xs = TextStyle(fontSize: 12, height: 16 / 12);
  static const sm = TextStyle(fontSize: 13, height: 18 / 13);
  static const base = TextStyle(fontSize: 14, height: 20 / 14);
  static const md = TextStyle(fontSize: 16, height: 24 / 16);
  static const lg = TextStyle(fontSize: 18, height: 26 / 18);
  static const xl = TextStyle(fontSize: 20, height: 28 / 20);
  static const xxl = TextStyle(fontSize: 24, height: 32 / 24);
  static const xxxl = TextStyle(fontSize: 32, height: 40 / 32);
  static const xxxxl = TextStyle(fontSize: 40, height: 48 / 40);

  static const weightRegular = FontWeight.w400;
  static const weightMedium = FontWeight.w500;
  static const weightSemibold = FontWeight.w600;
  static const weightBold = FontWeight.w700;

  /// Numeric/tabular text (token counts, byte sizes, hashes) — always
  /// monospace, matching web's `--font-mono` convention.
  static TextStyle mono(TextStyle base) =>
      base.copyWith(fontFamily: fontFamilyMono, fontFeatures: const [
        FontFeature.tabularFigures(),
      ]);
}
