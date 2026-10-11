import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// A small caps label above a group of rows ("DATA & STORAGE"): the one
/// section-heading style for settings-like lists, so the grouping reads
/// without borders or boxes.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4,
          AppSpacing.s5,
          AppSpacing.s4,
          AppSpacing.s2,
        ),
        child: Text(
          label.toUpperCase(),
          style: AppTypography.xs.copyWith(
            color: AppColors.textSecondary,
            fontWeight: AppTypography.weightSemibold,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
