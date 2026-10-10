import 'package:flutter/material.dart';

import '../../../../shared/tokens/app_colors.dart';
import '../../../../shared/tokens/app_spacing.dart';
import '../../data/graph_models.dart';
import '../models/graph_node.dart';

/// One document in the graph: a glossy dot with a soft glow, inside a touch
/// target no smaller than [AppSpacing.minTouchTarget]. A search match or the
/// selected node gets a ring and a label; with a search active, everything
/// else dims.
class GraphNodeDot extends StatelessWidget {
  const GraphNodeDot({
    super.key,
    required this.node,
    required this.matched,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final GraphNodeData node;
  final bool matched;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = node.type;
    final color = type.color;
    final radius = type.baseRadius;
    final opacity = dimmed ? 0.2 : 1.0;
    final emphasised = matched || selected;
    // A selected node is an expanded one, and its title is in the panel; the
    // label would sit on top of its own satellites. Only a search match gets
    // one.
    final labelled = matched && !dimmed;
    final glow = radius * (matched ? 6 : (selected ? 5 : 4));
    const target = AppSpacing.minTouchTarget;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: target,
        height: target,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            IgnorePointer(
              child: Container(
                width: glow * 2,
                height: glow * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withValues(
                        alpha: (matched ? 0.30 : 0.16) * opacity,
                      ),
                      color.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              key: Key('graph_node_${node.id}'),
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: opacity),
                border: emphasised
                    ? Border.all(color: color, width: selected ? 2 : 1.5)
                    : null,
              ),
              foregroundDecoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.45, -0.45),
                  radius: 0.5,
                  colors: [
                    Colors.white.withValues(alpha: 0.45 * opacity),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            if (labelled)
              Positioned(
                top: target / 2 + radius + 4,
                left: -80,
                right: -80,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgBase.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        node.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: matched
                              ? AppColors.accentSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A link between two documents: a thin line that fades with length.
class GraphEdgeLine extends StatelessWidget {
  const GraphEdgeLine({super.key, required this.length});

  final double length;

  @override
  Widget build(BuildContext context) {
    final alpha = (0.32 - length / 1400).clamp(0.06, 0.32);
    return SizedBox(
      width: length,
      height: 1.2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accentSecondary.withValues(alpha: alpha),
              AppColors.accentPrimary.withValues(alpha: alpha),
            ],
          ),
        ),
      ),
    );
  }
}
