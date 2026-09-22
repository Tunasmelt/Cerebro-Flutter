import 'package:flutter/material.dart';

import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';

/// Placeholder for the Chat destination — real chat/RAG conversation UI
/// is a later phase, not yet scoped in `phases-and-gates.md`. This
/// exists now so Milestone 1.2's app shell has a real screen at every
/// nav destination instead of a dangling route.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Center(
        child: Column(
          key: const Key('chat_placeholder'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(
              'Chat',
              style: AppTypography.lg.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.s1),
            Text(
              'Coming in a later phase',
              style: AppTypography.sm.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
