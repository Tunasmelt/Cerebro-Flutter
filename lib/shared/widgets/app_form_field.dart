import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// A label above any form control, with the same gap below as [AppTextField]
/// uses. For dialogs that need a [TextFormField] with a validator or a
/// dropdown, so every field in a form reads the same way and the controls
/// never touch each other.
///
/// The wrapped control should not set its own `labelText`.
class AppFormField extends StatelessWidget {
  const AppFormField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.xs.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s1),
          child,
        ],
      ),
    );
  }
}
