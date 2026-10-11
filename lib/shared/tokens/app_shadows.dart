import 'package:flutter/painting.dart';

/// Elevation, ported from the web `shadows.css`: soft and diffuse, never a
/// hard drop shadow — on a dark surface depth comes from a glow, not a crisp
/// edge.
///
/// The glows are for the one interactive/primary element on a view (a pressed
/// card, the primary action, a pulsing node). Used broadly they stop reading
/// as emphasis.
abstract final class AppShadows {
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x4D000000), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x73000000), blurRadius: 48, offset: Offset(0, 16)),
    BoxShadow(color: Color(0x4D000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// rgba(139,92,246,.35) ring + a soft violet bloom.
  static const List<BoxShadow> glowViolet = [
    BoxShadow(color: Color(0x598B5CF6), spreadRadius: 1),
    BoxShadow(color: Color(0x2E8B5CF6), blurRadius: 28, offset: Offset(0, 8)),
  ];

  /// rgba(45,212,191,.3) ring + a soft teal bloom.
  static const List<BoxShadow> glowTeal = [
    BoxShadow(color: Color(0x4D2DD4BF), spreadRadius: 1),
    BoxShadow(color: Color(0x242DD4BF), blurRadius: 28, offset: Offset(0, 8)),
  ];
}
