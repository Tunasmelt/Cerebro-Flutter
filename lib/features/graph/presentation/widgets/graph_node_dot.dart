import 'package:flutter/material.dart';

import '../../../../shared/tokens/app_colors.dart';
import '../../../../shared/tokens/app_spacing.dart';
import '../../data/graph_models.dart';
import '../models/graph_node.dart';

/// One document in the graph: a glossy dot with a soft glow, inside a touch
/// target no smaller than [AppSpacing.minTouchTarget]. A search match or the
/// selected node gets a ring and a label; with a search active, everything
/// else dims.
///
/// When [pulsing], the dot swells, brightens toward white and sends out a
/// ring that fades as [pulse] runs from 0 to 1 — the retrieval-replay
/// animation: this document was just drawn on to answer a question. The
/// animation is the screen's; the dot only listens to it, so a pulse repaints
/// the pulsing dots and nothing else.
class GraphNodeDot extends StatelessWidget {
  const GraphNodeDot({
    super.key,
    required this.node,
    required this.matched,
    required this.selected,
    required this.dimmed,
    required this.onTap,
    this.pulsing = false,
    this.pulse,
    this.reduceMotion = false,
  });

  final GraphNodeData node;
  final bool matched;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  /// This document is part of the current pulse.
  final bool pulsing;

  /// Progress of the current pulse, 0 (just started) to 1 (finished).
  final Animation<double>? pulse;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final animation = pulsing && !reduceMotion ? pulse : null;
    return Semantics(
      label: '${node.title}, ${node.type.label}',
      button: true,
      selected: selected,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: AppSpacing.minTouchTarget,
            height: AppSpacing.minTouchTarget,
            child: animation == null
                ? _body(pulsing && reduceMotion ? 0.8 : 0)
                : AnimatedBuilder(
                    animation: animation,
                    // 1 as the pulse starts, fading to 0 as it ends.
                    builder: (context, _) => _body(1 - animation.value),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _body(double intensity) {
    final type = node.type;
    final color = type.color;
    final opacity = dimmed ? 0.2 : 1.0;
    final emphasised = matched || selected;
    // A selected node is an expanded one, and its title is in the panel. Only
    // a search match gets a label.
    final labelled = matched && !dimmed;
    final radius = type.baseRadius * (1 + 0.5 * intensity);
    final glow = type.baseRadius * (matched ? 6 : (selected ? 5 : 4));
    const target = AppSpacing.minTouchTarget;
    final lit = Color.lerp(color, Colors.white, 0.55 * intensity)!;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (intensity > 0)
          IgnorePointer(
            child: Container(
              key: Key('graph_pulse_${node.id}'),
              // The ring starts at the dot and grows as it fades.
              width: type.baseRadius * 2 * (1.6 + 4.5 * (1 - intensity)),
              height: type.baseRadius * 2 * (1.6 + 4.5 * (1 - intensity)),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.18 * intensity),
                border: Border.all(
                  color: color.withValues(alpha: 0.75 * intensity),
                  width: 2,
                ),
              ),
            ),
          ),
        IgnorePointer(
          child: Container(
            width: glow * 2,
            height: glow * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: (matched ? 0.30 : 0.16) * opacity),
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
            color: lit.withValues(alpha: opacity),
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
