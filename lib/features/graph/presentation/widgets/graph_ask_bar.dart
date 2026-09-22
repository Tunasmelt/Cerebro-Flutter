import 'package:flutter/material.dart';

import '../../../../shared/tokens/app_colors.dart';
import '../../../../shared/tokens/app_radius.dart';
import '../../../../shared/tokens/app_spacing.dart';
import '../../../../shared/tokens/app_typography.dart';

/// Bottom "ask about your documents" bar, ported from Brain.tsx's ask
/// input. Submitting is a stub here (`onAsk` callback) — this wireframe
/// pass does not wire real navigation to chat, per the task constraints;
/// a later milestone plugs a real `onAsk` in that pushes the chat route.
class GraphAskBar extends StatelessWidget {
  const GraphAskBar({
    super.key,
    required this.controller,
    required this.onAsk,
  });

  final TextEditingController controller;
  final ValueChanged<String> onAsk;

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
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHover,
                  borderRadius: AppRadius.mdRadius,
                ),
                alignment: Alignment.center,
                child: Text(
                  'history',
                  style: AppTypography.xs.copyWith(color: AppColors.grayDim),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: AppTypography.sm.copyWith(color: AppColors.textPrimary),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) onAsk(v);
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    hintText: 'Ask about your documents…',
                    hintStyle:
                        AppTypography.sm.copyWith(color: AppColors.grayDim),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                  ),
                ),
              ),
              SizedBox(
                height: AppSpacing.minTouchTarget,
                child: TextButton(
                  onPressed: hasText ? () => onAsk(controller.text) : null,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    disabledBackgroundColor:
                        AppColors.accentPrimary.withValues(alpha: 0.5),
                    foregroundColor: AppColors.textOnAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdRadius,
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
                  ),
                  child: const Text(
                    'Ask',
                    style: TextStyle(
                      fontSize: 12,
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
