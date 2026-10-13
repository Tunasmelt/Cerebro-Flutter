import 'package:flutter/material.dart';

import '../../../../shared/tokens/app_colors.dart';
import '../../../../shared/tokens/app_radius.dart';
import '../../../../shared/tokens/app_spacing.dart';
import '../../../../shared/tokens/app_typography.dart';

/// Floating search chrome that overlays the graph canvas, adapted from
/// Brain.tsx's top-center search bar + match-count pill. Same behavior:
/// typing dims non-matching nodes rather than filtering them out, so
/// the surrounding graph structure stays visible for context.
class GraphSearchBar extends StatelessWidget {
  const GraphSearchBar({
    super.key,
    required this.controller,
    required this.query,
    required this.matchCount,
    required this.onChanged,
    required this.onClear,
    this.onNext,
  });

  final TextEditingController controller;
  final String query;
  final int matchCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.isNotEmpty;
    return Column(
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
          decoration: BoxDecoration(
            color: AppColors.bgElevated.withValues(alpha: 0.92),
            borderRadius: AppRadius.lgRadius,
            border: Border.all(
              color: hasQuery
                  ? AppColors.accentSecondary.withValues(alpha: 0.35)
                  : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 16,
                color: hasQuery ? AppColors.accentSecondary : AppColors.grayDim,
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: AppTypography.sm.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    // Every state, not just `border`: the app theme sets the
                    // per-state borders, which would draw a second box inside
                    // this container.
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    hintText: 'Search nodes…',
                    hintStyle: AppTypography.sm.copyWith(
                      color: AppColors.grayDim,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s3,
                    ),
                    // The text itself is 13px; the field is still a 44px target.
                    constraints: const BoxConstraints(
                      minHeight: AppSpacing.minTouchTarget,
                    ),
                  ),
                ),
              ),
              if (hasQuery)
                SizedBox(
                  width: AppSpacing.minTouchTarget,
                  height: AppSpacing.minTouchTarget,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Clear search',
                    iconSize: 14,
                    icon: const Icon(Icons.close, color: AppColors.grayDim),
                    onPressed: onClear,
                  ),
                ),
            ],
          ),
        ),
        if (hasQuery) ...[
          const SizedBox(height: AppSpacing.s1),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s2,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.accentSecondarySubtle,
              borderRadius: AppRadius.pillRadius,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$matchCount match${matchCount == 1 ? '' : 'es'}',
                  style: AppTypography.xs.copyWith(
                    color: AppColors.accentSecondary,
                  ),
                ),
                IconButton(
                  key: const Key('graph_next_match'),
                  tooltip: 'Next match',
                  onPressed: matchCount > 0 ? onNext : null,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
