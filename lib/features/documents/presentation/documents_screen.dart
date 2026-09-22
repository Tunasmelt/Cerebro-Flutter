import 'package:flutter/material.dart';

import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';

/// Placeholder for the Documents destination — real document list/detail
/// and upload flow are Phase 2 (Milestones 2.1–2.2). This exists now so
/// Milestone 1.2's app shell has a real screen at every nav destination
/// instead of a dangling route.
class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Center(
        child: Column(
          key: const Key('documents_placeholder'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.description_outlined,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(
              'Documents',
              style: AppTypography.lg.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.s1),
            Text(
              'Coming in Phase 2',
              style: AppTypography.sm.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
