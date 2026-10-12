import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/widgets/ask_field.dart';

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
    this.enabled = true,
    this.busy = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onAsk;
  final bool enabled;
  final bool busy;

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
                child: AskField(
                  inputKey: const Key('graph_ask_input'),
                  controller: controller,
                  enabled: enabled,
                  compact: true,
                ),
              ),
              SizedBox(
                height: AppSpacing.minTouchTarget,
                child: TextButton(
                  onPressed: hasText && enabled && !busy
                      ? () {
                          HapticFeedback.lightImpact();
                          onAsk(controller.text);
                        }
                      : null,
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
