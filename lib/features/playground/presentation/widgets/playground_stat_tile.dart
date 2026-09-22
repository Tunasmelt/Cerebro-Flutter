import 'package:flutter/material.dart';

import '../../../../shared/tokens/app_colors.dart';
import '../../../../shared/tokens/app_typography.dart';

/// One labelled value in the Playground stats card (INPUT / OUTPUT /
/// COST / LATENCY). Label is a muted caps caption, value is teal
/// monospace per the numeric-values-are-mono rule.
class PlaygroundStatTile extends StatelessWidget {
  const PlaygroundStatTile({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.xs.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.mono(AppTypography.lg).copyWith(
            color: AppColors.accentSecondary,
            fontWeight: AppTypography.weightSemibold,
          ),
        ),
      ],
    );
  }
}
