import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../shared/tokens/app_colors.dart';
import '../models/graph_node.dart';

/// One deterministically-placed background star. Generated once (not
/// per frame) with the same low-discrepancy trick Brain.tsx uses
/// (`i * 137.508`), so the field looks scattered rather than gridded
/// without needing a random seed or per-frame animation work.
class _Star {
  const _Star(this.dx, this.dy, this.radius, this.alpha);

  final double dx;
  final double dy;
  final double radius;
  final double alpha;
}

final List<_Star> _stars = List.generate(70, (i) {
  final dx = (i * 137.508) % 1.0;
  final dy = (i * 97.319) % 1.0;
  final radius = i % 3 == 0 ? 1.2 : 0.7;
  final alpha = 0.10 + (i % 7) * 0.035;
  return _Star(dx, dy, radius, alpha);
});

/// Paints the starfield background, edges, and nodes for the brain
/// graph. Node/edge positions are static (fractional coordinates
/// resolved against the canvas size) rather than physics-driven — see
/// `GraphNode.position`'s doc comment for why that's a deliberate
/// simplification, not a missing feature: the same painter would work
/// unchanged if `nodes` started arriving from a live force-directed tick.
class GraphCanvasPainter extends CustomPainter {
  GraphCanvasPainter({
    required this.nodes,
    required this.edges,
    required this.query,
    required this.selectedNodeId,
    required this.pulse,
  }) : super();

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final String query;

  /// Null when nothing is selected.
  final int? selectedNodeId;

  /// 0..1, looped externally by an [AnimationController] to drive a
  /// gentle pulse ring around the selected/matched node — the one bit
  /// of "alive" motion this wireframe keeps from Brain.tsx's RAF loop,
  /// without re-implementing the full physics tick.
  final double pulse;

  Offset _resolve(GraphNode node, Size size) =>
      Offset(node.position.dx * size.width, node.position.dy * size.height);

  GraphNode? _byId(int id) => nodes.where((n) => n.id == id).firstOrNull;

  bool _matches(GraphNode node) {
    if (query.isEmpty) return false;
    return node.label.toLowerCase().contains(query.toLowerCase());
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = AppColors.bgBase;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Static starfield — a subtle texture behind the graph, standing in
    // for Brain.tsx's twinkling canvas stars without a per-frame cost.
    final starPaint = Paint();
    for (final star in _stars) {
      starPaint.color = Colors.white.withValues(alpha: star.alpha);
      canvas.drawCircle(
        Offset(star.dx * size.width, star.dy * size.height),
        star.radius,
        starPaint,
      );
    }

    final anyQuery = query.isNotEmpty;

    // Edges first, under the nodes.
    for (final edge in edges) {
      final a = _byId(edge.fromId);
      final b = _byId(edge.toId);
      if (a == null || b == null) continue;
      final pa = _resolve(a, size);
      final pb = _resolve(b, size);
      final dist = (pb - pa).distance;
      final alpha = math.max(0.06, 0.32 - dist / 1400);
      final shader = ui.Gradient.linear(pa, pb, [
        AppColors.accentSecondary.withValues(alpha: alpha),
        AppColors.accentPrimary.withValues(alpha: alpha),
      ]);
      final edgePaint = Paint()
        ..shader = shader
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(pa, pb, edgePaint);
    }

    // Nodes on top.
    for (final node in nodes) {
      final isSelected = node.id == selectedNodeId;
      final isMatch = _matches(node);
      final isDimmed = anyQuery && !isMatch && !isSelected;
      final center = _resolve(node, size);
      final opacity = isDimmed ? 0.2 : 1.0;

      // Soft radial glow behind the node.
      final glowRadius =
          node.baseRadius * (isMatch ? 6 : isSelected ? 5 : 4);
      final glowPaint = Paint()
        ..shader = ui.Gradient.radial(center, glowRadius, [
          node.type.color.withValues(alpha: (isMatch ? 0.30 : 0.16) * opacity),
          node.type.color.withValues(alpha: 0),
        ]);
      canvas.drawCircle(center, glowRadius, glowPaint);

      // Pulse ring for a selected or matched node.
      if (isMatch || isSelected) {
        final pulseExtent = 4 + pulse * 4;
        final ringPaint = Paint()
          ..color = node.type.color.withValues(alpha: 0.45 * opacity)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(
          center,
          node.baseRadius + 5 + pulseExtent,
          ringPaint,
        );
      }

      // Solid node dot.
      final dotPaint = Paint()
        ..color = node.type.color.withValues(alpha: opacity);
      canvas.drawCircle(center, node.baseRadius, dotPaint);

      // Selection ring, crisp and static (distinct from the soft pulse).
      if (isSelected) {
        final selPaint = Paint()
          ..color = node.type.color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(center, node.baseRadius + 5, selPaint);
      }

      // Small specular highlight for the glossy look Brain.tsx uses.
      final specPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.45 * opacity);
      canvas.drawCircle(
        center.translate(-node.baseRadius * 0.28, -node.baseRadius * 0.28),
        node.baseRadius * 0.38,
        specPaint,
      );

      // Floating label chip for a matched/selected node.
      if ((isMatch || isSelected) && !isDimmed) {
        _paintLabelChip(canvas, node, center, isMatch);
      }
    }
  }

  void _paintLabelChip(
    Canvas canvas,
    GraphNode node,
    Offset center,
    bool isMatch,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: node.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isMatch ? AppColors.accentSecondary : AppColors.textPrimary,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const pad = 6.0;
    final chipRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(
          center.dx,
          center.dy + node.baseRadius + 8 + textPainter.height / 2,
        ),
        width: textPainter.width + pad * 2,
        height: textPainter.height + 6,
      ),
      const Radius.circular(4),
    );
    final chipPaint = Paint()..color = AppColors.bgBase.withValues(alpha: 0.88);
    canvas.drawRRect(chipRect, chipPaint);
    textPainter.paint(
      canvas,
      Offset(chipRect.left + pad, chipRect.top + 3),
    );
  }

  @override
  bool shouldRepaint(covariant GraphCanvasPainter oldDelegate) {
    return oldDelegate.query != query ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.pulse != pulse ||
        oldDelegate.nodes != nodes ||
        oldDelegate.edges != edges;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
