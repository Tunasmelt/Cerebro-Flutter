import 'package:flutter/rendering.dart';

/// Ported from `Cerebro 2.0/apps/web/src/app/styles/tokens/radius.css`.
abstract final class AppRadius {
  static const sm = 6.0;
  static const md = 8.0;
  static const lg = 12.0;

  /// Pills and badges only.
  static const pill = 999.0;

  static const smRadius = BorderRadius.all(Radius.circular(sm));
  static const mdRadius = BorderRadius.all(Radius.circular(md));
  static const lgRadius = BorderRadius.all(Radius.circular(lg));
  static const pillRadius = BorderRadius.all(Radius.circular(pill));
}
