import 'package:flutter/material.dart';

import '../../../../shared/tokens/app_colors.dart';
import '../../../../shared/tokens/app_radius.dart';
import '../../../../shared/tokens/app_spacing.dart';
import '../../../../shared/tokens/app_typography.dart';
import '../models/graph_node.dart';

/// Dismissible bottom-left legend explaining node color-by-type, ported
/// from Brain.tsx's legend card. Kept bottom-left on mobile too (rather
/// than moved) since it doesn't compete with the bottom ask bar, which
/// is centered.
class GraphLegend extends StatelessWidget {
  const GraphLegend({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: AppColors.bgElevated.withValues(alpha: 0.92),
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'node color = type',
            style: AppTypography.mono(AppTypography.xs)
                .copyWith(color: AppColors.grayDim),
          ),
          const SizedBox(height: AppSpacing.s2),
          for (final type in GraphNodeType.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: type.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Text(
                    type.label,
                    style: AppTypography.xs.copyWith(color: AppColors.gray),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.s1),
          SizedBox(
            height: AppSpacing.minTouchTarget,
            child: TextButton(
              onPressed: onDismiss,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, AppSpacing.minTouchTarget),
                foregroundColor: AppColors.grayDim,
              ),
              child: const Text('dismiss', style: AppTypography.xs),
            ),
          ),
        ],
      ),
    );
  }
}
