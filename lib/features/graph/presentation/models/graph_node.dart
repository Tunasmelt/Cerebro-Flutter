import 'package:flutter/material.dart';

import '../../../../shared/tokens/app_colors.dart';

/// Node type drives node color per `architecture-and-spec.md` §5 and
/// Brain.tsx's `COLOR_MAP`: document = violet, image = teal,
/// sealed = amber. Amber is reserved exclusively for sealed nodes — see
/// `CLAUDE.md` naming/color discipline.
enum GraphNodeType { document, image, sealed }

extension GraphNodeTypeX on GraphNodeType {
  Color get color {
    switch (this) {
      case GraphNodeType.document:
        return AppColors.accentPrimary;
      case GraphNodeType.image:
        return AppColors.accentSecondary;
      case GraphNodeType.sealed:
        return AppColors.accentLocked;
    }
  }

  String get label {
    switch (this) {
      case GraphNodeType.document:
        return 'document';
      case GraphNodeType.image:
        return 'image';
      case GraphNodeType.sealed:
        return 'sealed';
    }
  }
}

/// A single graph node. `position` is fractional (0..1 of the canvas
/// size), not absolute pixels — this is what lets a real force-directed
/// layout (or the server-driven cluster projection described in
/// architecture-and-spec.md §5) drop in later without callers changing:
/// only the numbers that populate this field would change, never the
/// rendering code that consumes it.
///
/// Cluster membership (`type` here, standing in for real server cluster
/// IDs later) is the only thing that's semantically real; `position` is
/// cosmetic, exactly as §5 specifies.
@immutable
class GraphNode {
  const GraphNode({
    required this.id,
    required this.label,
    required this.type,
    required this.position,
    this.baseRadius = 10,
  });

  final int id;
  final String label;
  final GraphNodeType type;

  /// Fractional position within the canvas, both axes in [0, 1].
  final Offset position;

  /// Visual dot radius in logical pixels before any selection/match
  /// emphasis is applied. Matches Brain.tsx's per-type size (document
  /// 10, image 9, sealed 7).
  final double baseRadius;
}

@immutable
class GraphEdge {
  const GraphEdge(this.fromId, this.toId);

  final int fromId;
  final int toId;
}

/// Static/mock node + edge data standing in for a real `/graph/nodes`
/// and `/graph/edges` response (see architecture-and-spec.md §5). Labels
/// and edge shape are carried over from Brain.tsx's `DOCS`/`EDGES` so
/// the wireframe reads like the same vault, just laid out by hand
/// instead of by a live physics tick — positions below are a plausible
/// "already settled" arrangement, not a computed one.
abstract final class MockGraphData {
  static const List<GraphNode> nodes = [
    GraphNode(
      id: 0,
      label: 'Full Stack AI Developer.pdf',
      type: GraphNodeType.document,
      position: Offset(0.50, 0.42),
    ),
    GraphNode(
      id: 1,
      label: 'BrightPro Paper',
      type: GraphNodeType.document,
      position: Offset(0.74, 0.20),
    ),
    GraphNode(
      id: 2,
      label: 'IR Misses the Mark',
      type: GraphNodeType.document,
      position: Offset(0.82, 0.34),
    ),
    GraphNode(
      id: 3,
      label: 'Yaras Schedule',
      type: GraphNodeType.image,
      position: Offset(0.16, 0.58),
      baseRadius: 9,
    ),
    GraphNode(
      id: 4,
      label: 'ForkedRap Architecture',
      type: GraphNodeType.document,
      position: Offset(0.34, 0.56),
    ),
    GraphNode(
      id: 5,
      label: 'Junior IT Specialist',
      type: GraphNodeType.document,
      position: Offset(0.24, 0.70),
    ),
    GraphNode(
      id: 6,
      label: 'Retention Marketing',
      type: GraphNodeType.document,
      position: Offset(0.18, 0.84),
    ),
    GraphNode(
      id: 7,
      label: 'Screenshot 2026-08-23',
      type: GraphNodeType.image,
      position: Offset(0.09, 0.40),
      baseRadius: 9,
    ),
    GraphNode(
      id: 8,
      label: 'PyPI Recovery',
      type: GraphNodeType.sealed,
      position: Offset(0.30, 0.26),
      baseRadius: 7,
    ),
    GraphNode(
      id: 9,
      label: 'Consensus Algorithms',
      type: GraphNodeType.document,
      position: Offset(0.63, 0.28),
    ),
    GraphNode(
      id: 10,
      label: '87088384.jpg',
      type: GraphNodeType.image,
      position: Offset(0.66, 0.70),
      baseRadius: 9,
    ),
    GraphNode(
      id: 11,
      label: '32622956.jpg',
      type: GraphNodeType.image,
      position: Offset(0.82, 0.80),
      baseRadius: 9,
    ),
  ];

  static const List<GraphEdge> edges = [
    GraphEdge(0, 9),
    GraphEdge(0, 4),
    GraphEdge(1, 2),
    GraphEdge(1, 9),
    GraphEdge(2, 9),
    GraphEdge(3, 6),
    GraphEdge(4, 5),
    GraphEdge(5, 6),
    GraphEdge(7, 3),
    GraphEdge(8, 0),
    GraphEdge(10, 7),
    GraphEdge(11, 10),
  ];
}
