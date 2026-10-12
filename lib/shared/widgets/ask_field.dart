import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// Shared multiline question input; sending remains an explicit action.
class AskField extends StatelessWidget {
  const AskField({
    super.key,
    required this.controller,
    this.inputKey,
    this.enabled = true,
    this.compact = false,
  });
  final TextEditingController controller;
  final Key? inputKey;
  final bool enabled;
  final bool compact;

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: AppRadius.lgRadius,
    borderSide: BorderSide(color: color),
  );

  @override
  Widget build(BuildContext context) => TextField(
    key: inputKey,
    controller: controller,
    enabled: enabled,
    minLines: 1,
    maxLines: 5,
    textCapitalization: TextCapitalization.sentences,
    keyboardType: TextInputType.multiline,
    textInputAction: TextInputAction.newline,
    style: (compact ? AppTypography.sm : AppTypography.base).copyWith(
      color: AppColors.textPrimary,
    ),
    decoration: InputDecoration(
      hintText: 'Ask your documents…',
      hintStyle: AppTypography.base.copyWith(color: AppColors.textDisabled),
      isDense: compact,
      filled: !compact,
      fillColor: AppColors.bgElevated,
      contentPadding: EdgeInsets.symmetric(
        horizontal: compact ? 0 : AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      border: compact ? InputBorder.none : _border(AppColors.borderDefault),
      enabledBorder: compact
          ? InputBorder.none
          : _border(AppColors.borderDefault),
      focusedBorder: compact
          ? InputBorder.none
          : _border(AppColors.accentPrimaryBorder),
      disabledBorder: compact
          ? InputBorder.none
          : _border(AppColors.borderDefault),
      errorBorder: compact ? InputBorder.none : null,
      focusedErrorBorder: compact ? InputBorder.none : null,
    ),
  );
}
