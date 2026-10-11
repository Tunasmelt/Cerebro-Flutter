import 'package:flutter/animation.dart';

/// Motion tokens, ported from the web `motion.css`.
///
/// Everything moves softly: physics-like, never bouncy. [pulse] is reserved
/// for the retrieval pulse alone — fast and sharp is what makes it read as
/// "this document was just drawn on".
abstract final class AppMotion {
  static const Curve soft = Cubic(0.4, 0, 0.2, 1);
  static const Curve pulse = Cubic(0.16, 1, 0.3, 1);

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 360);
  static const Duration pulseDuration = Duration(milliseconds: 480);
}
