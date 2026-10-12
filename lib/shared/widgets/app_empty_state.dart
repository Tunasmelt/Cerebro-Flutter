import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// What a screen shows when there is nothing to show yet: a small icon, one
/// line saying what this place is, one line saying what to do about it, and
/// (optionally) the action that does it. Replaces a dozen bare grey `Text`s.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'an action needs both a label and a callback',
       );

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    // Centred when it fits; scrolls when it does not (a small phone, large
    // text, landscape) rather than overflowing.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        // Always scrollable so a parent RefreshIndicator can pull even when
        // the content fits.
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  key: const Key('app_empty_state'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated,
                        borderRadius: AppRadius.lgRadius,
                        border: Border.all(color: AppColors.borderDefault),
                      ),
                      child: Icon(
                        icon,
                        size: 26,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTypography.lg.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: AppTypography.weightMedium,
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: AppSpacing.s1),
                      Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: AppTypography.sm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (actionLabel != null) ...[
                      const SizedBox(height: AppSpacing.s5),
                      FilledButton(
                        key: const Key('app_empty_action'),
                        onPressed: onAction,
                        child: Text(actionLabel!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
