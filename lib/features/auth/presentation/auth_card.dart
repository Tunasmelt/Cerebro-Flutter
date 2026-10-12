import 'package:flutter/material.dart';

import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';

/// The Cerebro mark and wordmark above the sign-in and sign-up cards: a
/// violet-washed tile with the brain glyph, then the name. The one branded
/// moment on the auth screens.
class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cerebro',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accentPrimary.withValues(alpha: 0.14),
              borderRadius: AppRadius.lgRadius,
              border: Border.all(
                color: AppColors.accentPrimary.withValues(alpha: 0.4),
              ),
            ),
            child: const Icon(
              Icons.psychology_outlined,
              size: 30,
              color: AppColors.accentPrimaryHover,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            'Cerebro',
            style: AppTypography.xl.copyWith(
              fontFamily: AppTypography.fontFamilyDisplay,
              fontWeight: AppTypography.weightBold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The elevated card the auth forms sit in. Fills the screen width up to a
/// cap instead of a fixed 360px, so it is comfortable on a small phone and
/// does not stretch on a tablet.
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child});

  final Widget child;

  static const double maxWidth = 440;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s6),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: AppRadius.lgRadius,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: child,
      ),
    );
  }
}

/// A red message strip (a rejected sign-in, mismatched passwords). One widget
/// for the three copies the auth screens had; announced to screen readers
/// when it appears.
class AuthMessage extends StatelessWidget {
  const AuthMessage(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        decoration: BoxDecoration(
          color: AppColors.dangerSubtle,
          borderRadius: AppRadius.mdRadius,
        ),
        child: Text(
          message,
          style: AppTypography.xs.copyWith(color: AppColors.dangerHover),
        ),
      ),
    );
  }
}
