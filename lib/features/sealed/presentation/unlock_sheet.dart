import 'package:flutter/material.dart';

import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';

/// Visual state of the unlock bottom sheet.
///
/// Presentation-layer only — there is no sealed-tier crypto or backend
/// call behind this enum. A real integration would drive [error] from
/// whatever the unlock request actually returns, and must keep the
/// message generic (see [UnlockSheet]'s error copy below): per
/// architecture-and-spec.md §4 and CLAUDE.md's naming discipline, a
/// failed unlock never hints at *why* it failed.
enum UnlockSheetStatus {
  /// Sheet is idle — empty or in-progress passphrase entry, no error.
  idle,

  /// Unlock request in flight.
  loading,

  /// Unlock failed. Message stays generic — no hint of cause (wrong
  /// passphrase vs. corrupted blob vs. anything else).
  error,
}

/// The "Unlock document" bottom sheet for the sealed document detail
/// screen.
///
/// Purely presentational: the caller owns the passphrase [controller],
/// the obscure-text toggle, and the [status], and supplies callbacks
/// for Unlock/Cancel/visibility-toggle. No sealed-tier crypto or
/// network call happens here — wiring that up belongs in
/// `core/` per CLAUDE.md ("this client renders state and calls
/// endpoints; it does not reimplement ... sealing logic locally").
class UnlockSheet extends StatelessWidget {
  const UnlockSheet({
    super.key,
    required this.status,
    required this.controller,
    required this.obscureText,
    required this.onToggleObscureText,
    required this.onUnlock,
    required this.onCancel,
  });

  final UnlockSheetStatus status;
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onToggleObscureText;
  final VoidCallback onUnlock;
  final VoidCallback onCancel;

  bool get _isError => status == UnlockSheetStatus.error;
  bool get _isLoading => status == UnlockSheetStatus.loading;

  @override
  Widget build(BuildContext context) {
    final fieldBorderColor =
        _isError ? AppColors.danger : AppColors.borderDefault;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s3,
        AppSpacing.s6,
        AppSpacing.s6,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.lg),
          topRight: Radius.circular(AppRadius.lg),
        ),
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle. Purely decorative — the sheet doesn't actually
          // support drag-to-dismiss in this presentation-layer build.
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.s5),
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: AppRadius.pillRadius,
              ),
            ),
          ),
          Text(
            'Unlock document',
            style: AppTypography.xl.copyWith(
              fontFamily: AppTypography.fontFamilyDisplay,
              fontWeight: AppTypography.weightBold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Enter your passphrase to decrypt and view this document on '
            'your device.',
            style:
                AppTypography.base.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s5),
          Text(
            'Passphrase',
            style: AppTypography.sm.copyWith(
              fontWeight: AppTypography.weightSemibold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          TextField(
            controller: controller,
            obscureText: obscureText,
            enabled: !_isLoading,
            style: AppTypography.base.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.lock_outline,
                color: _isError ? AppColors.danger : AppColors.textSecondary,
              ),
              suffixIcon: IconButton(
                constraints: const BoxConstraints(
                  minWidth: AppSpacing.minTouchTarget,
                  minHeight: AppSpacing.minTouchTarget,
                ),
                icon: Icon(
                  obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary,
                ),
                onPressed: onToggleObscureText,
                tooltip: obscureText ? 'Show passphrase' : 'Hide passphrase',
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.mdRadius,
                borderSide: BorderSide(color: fieldBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.mdRadius,
                borderSide: BorderSide(color: fieldBorderColor, width: 1.5),
              ),
              border: OutlineInputBorder(
                borderRadius: AppRadius.mdRadius,
                borderSide: BorderSide(color: fieldBorderColor),
              ),
            ),
          ),
          if (_isError) ...[
            const SizedBox(height: AppSpacing.s2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.error_outline,
                    color: AppColors.danger,
                    size: 16,
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(
                    // Generic on purpose — never hints at the actual
                    // cause of failure. See UnlockSheetStatus.error doc.
                    "Couldn't unlock this document. Try again.",
                    style:
                        AppTypography.sm.copyWith(color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.s5),
          SizedBox(
            width: double.infinity,
            height: AppSpacing.minTouchTarget + 4,
            child: ElevatedButton(
              onPressed: _isLoading ? null : onUnlock,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentLocked,
                foregroundColor: AppColors.textOnAccent,
                disabledBackgroundColor:
                    AppColors.accentLocked.withValues(alpha: 0.6),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.mdRadius,
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.textOnAccent,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Unlock',
                          style: AppTypography.base.copyWith(
                            fontWeight: AppTypography.weightSemibold,
                            color: AppColors.textOnAccent,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s2),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          SizedBox(
            width: double.infinity,
            height: AppSpacing.minTouchTarget,
            child: OutlinedButton(
              onPressed: _isLoading ? null : onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.borderDefault),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.mdRadius,
                ),
              ),
              child: Text(
                'Cancel',
                style: AppTypography.base.copyWith(
                  fontWeight: AppTypography.weightMedium,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
