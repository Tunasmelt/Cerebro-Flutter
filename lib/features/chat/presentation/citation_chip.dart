import 'package:flutter/material.dart';

import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';

/// The small numbered footnote chip drawn inline in an answer, e.g. [2].
///
/// [enabled] is false when the document it cites is known not to exist any
/// more: still drawn (the answer did cite it) but muted and inert, so it
/// never looks like a working link that goes nowhere.
class CitationChip extends StatelessWidget {
  const CitationChip({
    super.key,
    required this.number,
    required this.title,
    required this.enabled,
    required this.onTap,
  });

  final int number;
  final String title;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.accentPrimary : AppColors.textDisabled;
    return Semantics(
      button: enabled,
      label: enabled
          ? 'Source $number: $title'
          : 'Source $number: no longer available',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        // The chip is small to sit in a line of text; the padding around it
        // widens the tappable area without moving the text.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          // No `alignment:` on this Container: a Container with an alignment
          // expands to fill the width it is offered, and inside a line of text
          // that is the whole line — the chip became a full-width bar. The
          // Center below (widthFactor: 1) centres the number without growing.
          child: Container(
            constraints: const BoxConstraints(minWidth: 20),
            height: 20,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.accentPrimarySubtle
                  : AppColors.bgRaised,
              borderRadius: AppRadius.pillRadius,
              border: Border.all(
                color: enabled
                    ? AppColors.accentPrimaryBorder
                    : AppColors.borderDefault,
              ),
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                '$number',
                style: AppTypography.xs.copyWith(
                  color: color,
                  fontWeight: AppTypography.weightSemibold,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One source document under an answer: its title and the footnote numbers
/// that cite it. Full-size, so it is an easy tap target (the inline chips are
/// deliberately small).
class SourceChip extends StatelessWidget {
  const SourceChip({
    super.key,
    required this.title,
    required this.numbers,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final List<int> numbers;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = numbers.map((n) => '[$n]').join(' ');
    return Semantics(
      button: enabled,
      label: enabled
          ? 'Open source: $title'
          : 'Source no longer available: $title',
      excludeSemantics: true,
      child: Material(
        color: enabled ? AppColors.bgRaised : AppColors.bgElevated,
        borderRadius: AppRadius.mdRadius,
        child: InkWell(
          borderRadius: AppRadius.mdRadius,
          onTap: enabled ? onTap : null,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
              maxWidth: 260,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3,
              vertical: AppSpacing.s2,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdRadius,
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  enabled ? Icons.description_outlined : Icons.link_off_rounded,
                  size: 16,
                  color: enabled
                      ? AppColors.accentPrimary
                      : AppColors.textDisabled,
                ),
                const SizedBox(width: AppSpacing.s2),
                Text(
                  label,
                  style: AppTypography.xs.copyWith(
                    color: enabled
                        ? AppColors.accentPrimary
                        : AppColors.textDisabled,
                    fontWeight: AppTypography.weightSemibold,
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sm.copyWith(
                      color: enabled
                          ? AppColors.textPrimary
                          : AppColors.textDisabled,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
