import 'package:flutter/material.dart';

import '../../core/network/app_exception.dart';
import '../../core/network/error_presentation.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// The app's one inline error widget — per Milestone 1.3's exit
/// criteria, every screen shows a failed [AppException] through this,
/// never raw exception text or a bare `Text(error.toString())`.
///
/// Compact by default (fits inline under a form field or list, the
/// same footprint as `SignInScreen`'s existing error banner); pass
/// [expanded] for a full-section replacement (e.g. a whole screen's
/// body when its one piece of content failed to load).
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.exception,
    this.onRetry,
    this.expanded = false,
  });

  final AppException exception;
  final VoidCallback? onRetry;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final presentation = ErrorPresentation.of(exception);

    if (!expanded) {
      return Container(
        key: Key('error_view_${presentation.kind.name}'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        decoration: BoxDecoration(
          color: presentation.color.withValues(alpha: 0.12),
          borderRadius: AppRadius.mdRadius,
        ),
        child: Row(
          children: [
            Icon(presentation.icon, size: 16, color: presentation.color),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: Text(
                presentation.message,
                style: AppTypography.xs.copyWith(color: presentation.color),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: AppSpacing.s2),
              _RetryButton(color: presentation.color, onRetry: onRetry!),
            ],
          ],
        ),
      );
    }

    return Center(
      key: Key('error_view_${presentation.kind.name}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(presentation.icon, size: 40, color: presentation.color),
            const SizedBox(height: AppSpacing.s3),
            Text(
              presentation.message,
              textAlign: TextAlign.center,
              style: AppTypography.sm.copyWith(color: presentation.color),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.s4),
              _RetryButton(color: presentation.color, onRetry: onRetry!),
            ],
          ],
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.color, required this.onRetry});

  final Color color;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const Key('error_view_retry'),
      onPressed: onRetry,
      style: TextButton.styleFrom(foregroundColor: color, padding: EdgeInsets.zero),
      child: const Text('Retry'),
    );
  }
}
