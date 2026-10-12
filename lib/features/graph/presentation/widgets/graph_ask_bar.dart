import 'package:flutter/material.dart';

import '../../../../shared/tokens/app_colors.dart';
import '../../../../shared/tokens/app_radius.dart';
import '../../../../shared/tokens/app_spacing.dart';
import '../../../../shared/tokens/app_typography.dart';

/// Ask a real question over the graph or pick a conversation to replay.
/// The screen submits through the shared chat controller.
class GraphAskBar extends StatelessWidget {
  const GraphAskBar({
    super.key,
    required this.controller,
    required this.onAsk,
    this.onHistory,
  });

  final TextEditingController controller;
  final ValueChanged<String> onAsk;

  /// Opens the list of past conversations to replay on the graph.
  final VoidCallback? onHistory;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        return Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3,
            vertical: AppSpacing.s1,
          ),
          decoration: BoxDecoration(
            color: AppColors.bgElevated.withValues(alpha: 0.92),
            borderRadius: AppRadius.lgRadius,
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Row(
            children: [
              IconButton(
                key: const Key('graph_history'),
                tooltip: 'Past conversations',
                onPressed: onHistory,
                icon: const Icon(Icons.history_rounded, size: 20),
                color: AppColors.textSecondary,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: AppTypography.sm.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) onAsk(v);
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    hintText: 'Ask about your documents…',
                    hintStyle: AppTypography.sm.copyWith(
                      color: AppColors.grayDim,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s3,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: AppSpacing.minTouchTarget,
                child: TextButton(
                  onPressed: hasText ? () => onAsk(controller.text) : null,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    disabledBackgroundColor: AppColors.accentPrimary.withValues(
                      alpha: 0.5,
                    ),
                    foregroundColor: AppColors.textOnAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdRadius,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s3,
                    ),
                  ),
                  child: const Text(
                    'Ask',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: AppTypography.weightSemibold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
