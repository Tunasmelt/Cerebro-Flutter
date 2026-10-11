import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// A labelled text field: the label above, the field below. One widget for
/// every form in the app (sign-in, sign-up, account settings...), so spacing,
/// type and focus styling cannot drift apart between screens.
///
/// With [showVisibilityToggle] (for passwords) an eye button reveals or hides
/// the text; the button is a full-size touch target.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.showVisibilityToggle = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.errorText,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;

  /// Adds the show/hide button; only meaningful when [obscureText] is set.
  final bool showVisibilityToggle;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final bool enabled;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final obscured = widget.obscureText && !_revealed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTypography.xs.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s1),
        TextField(
          controller: widget.controller,
          obscureText: obscured,
          enabled: widget.enabled,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          onSubmitted: widget.onSubmitted,
          style: AppTypography.sm.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            errorText: widget.errorText,
            suffixIcon: widget.obscureText && widget.showVisibilityToggle
                ? IconButton(
                    key: const Key('app_text_field_toggle'),
                    tooltip: _revealed ? 'Hide' : 'Show',
                    onPressed: () => setState(() => _revealed = !_revealed),
                    icon: Icon(
                      _revealed
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
