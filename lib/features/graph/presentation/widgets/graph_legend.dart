import 'package:flutter/material.dart';

import '../../../../shared/tokens/app_colors.dart';
import '../../../../shared/tokens/app_radius.dart';
import '../../../../shared/tokens/app_spacing.dart';
import '../../../../shared/tokens/app_typography.dart';
import '../models/graph_node.dart';

/// What the node colours mean, as compact chips that are also filters: tap a
/// type to dim every node of it, tap again to bring them back. It replaces the
/// card that sat over the graph with a row that sits under the search bar and
/// teaches the colours while it works.
class GraphLegend extends StatelessWidget {
  const GraphLegend({super.key, required this.hidden, required this.onToggle});

  /// The types currently dimmed.
  final Set<GraphNodeType> hidden;
  final ValueChanged<GraphNodeType> onToggle;

  static String labelOf(GraphNodeType type) =>
      '${type.label[0].toUpperCase()}${type.label.substring(1)}';

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('graph_legend'),
      spacing: AppSpacing.s2,
      children: [
        for (final type in GraphNodeType.values)
          _TypeChip(
            type: type,
            active: !hidden.contains(type),
            onTap: () => onToggle(type),
          ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.type,
    required this.active,
    required this.onTap,
  });

  final GraphNodeType type;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = GraphLegend.labelOf(type);
    return Semantics(
      button: true,
      selected: active,
      label: '$label nodes, ${active ? 'shown' : 'dimmed'}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        key: Key('graph_legend_${type.name}'),
        onTap: onTap,
        borderRadius: AppRadius.pillRadius,
        child: ConstrainedBox(
          // The pill is small; the touch target is not.
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouchTarget,
          ),
          // widthFactor: shrink to the pill. A plain Center would take the
          // whole row, and the chips would stack one per line.
          child: Align(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s3,
                vertical: AppSpacing.s1,
              ),
              decoration: BoxDecoration(
                color: active
                    ? type.color.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: AppRadius.pillRadius,
                border: Border.all(
                  color: active
                      ? type.color.withValues(alpha: 0.5)
                      : AppColors.borderDefault,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? type.color : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: type.color),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Text(
                    label,
                    style: AppTypography.xs.copyWith(
                      color: active
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
