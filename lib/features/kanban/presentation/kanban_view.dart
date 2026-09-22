import 'package:flutter/material.dart';

import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';

/// Card priority. Colors intentionally use red/green/gray rather than
/// the amber the mockup's "Medium" dot suggests — amber is reserved
/// exclusively for sealed/locked UI per CLAUDE.md, and app_colors.dart
/// has no separate "orange" token to hardcode instead.
enum _Priority { high, medium, low }

extension on _Priority {
  Color get color => switch (this) {
    _Priority.high => AppColors.danger,
    _Priority.medium => AppColors.accentSuccess,
    _Priority.low => AppColors.textDisabled,
  };

  String get label => switch (this) {
    _Priority.high => 'High',
    _Priority.medium => 'Medium',
    _Priority.low => 'Low',
  };
}

class _KanbanCard {
  const _KanbanCard({
    required this.title,
    required this.description,
    required this.docRef,
    required this.priority,
    required this.issueId,
  });

  final String title;
  final String description;
  final String docRef;
  final _Priority priority;
  final String issueId;
}

class _KanbanColumn {
  const _KanbanColumn({
    required this.name,
    required this.dotColor,
    required this.cards,
    this.showDropPlaceholder = false,
  });

  final String name;
  final Color dotColor;
  final List<_KanbanCard> cards;
  final bool showDropPlaceholder;
}

const _mockColumns = <_KanbanColumn>[
  _KanbanColumn(
    name: 'Backlog',
    dotColor: AppColors.grayDim,
    cards: [
      _KanbanCard(
        title: 'Benchmark hybrid retrieval',
        description: 'Reproduce results from v3 paper on internal dataset.',
        docRef: 'hybrid-benchmarks.md',
        priority: _Priority.high,
        issueId: '#R-102',
      ),
      _KanbanCard(
        title: 'Map citation provenance',
        description: 'Track source documents and attribution paths.',
        docRef: 'doc:provenance-v1.2',
        priority: _Priority.medium,
        issueId: '#R-103',
      ),
      _KanbanCard(
        title: 'Evaluate long-context QA',
        description: 'Test 100K+ token documents with real user queries.',
        docRef: 'long-context-eval.pdf',
        priority: _Priority.low,
        issueId: '#R-104',
      ),
      _KanbanCard(
        title: 'Design onboarding flow',
        description: 'Improve new user activation and docs.',
        docRef: 'doc:onboarding-flow',
        priority: _Priority.low,
        issueId: '#R-105',
      ),
    ],
  ),
  _KanbanColumn(
    name: 'In Progress',
    dotColor: AppColors.accentSecondary,
    cards: [
      _KanbanCard(
        title: 'Tune reranker latency',
        description: 'Profile and optimize cross-encoder inference.',
        docRef: 'doc:arch-v3 §4.2',
        priority: _Priority.high,
        issueId: '#R-101',
      ),
      _KanbanCard(
        title: 'Implement graph clustering',
        description: 'Build community detection for research topics.',
        docRef: 'graph-clustering.md',
        priority: _Priority.medium,
        issueId: '#R-106',
      ),
      _KanbanCard(
        title: 'Add evaluation harness',
        description: 'Automate regression tests on benchmark set.',
        docRef: 'eval-harness.py',
        priority: _Priority.low,
        issueId: '#R-107',
      ),
    ],
  ),
  _KanbanColumn(
    name: 'Review',
    dotColor: AppColors.accentPrimary,
    cards: [
      _KanbanCard(
        title: 'Review graph clusters',
        description: 'Validate cluster quality and labels.',
        docRef: 'clusters-review.md',
        priority: _Priority.high,
        issueId: '#R-108',
      ),
      _KanbanCard(
        title: 'Finalize system documentation',
        description: 'Complete architecture diagrams and examples.',
        docRef: 'system-arch.pdf',
        priority: _Priority.medium,
        issueId: '#R-109',
      ),
    ],
    showDropPlaceholder: true,
  ),
];

/// The Kanban board content view: horizontally scrolling status columns,
/// matching `Mockups/7828735d-25f1-4841-b324-b304cd143d00.png`.
///
/// Cards are static/mock and non-draggable — `flutter_reorderable_grid`-
/// style drag-and-drop would need a new package dependency, which this
/// milestone is not authorized to add. The drag handle icon is rendered
/// for visual fidelity only.
class KanbanView extends StatelessWidget {
  const KanbanView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s2,
        AppSpacing.s4,
        AppSpacing.s4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final column in _mockColumns)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s4),
              child: _ColumnView(column: column),
            ),
        ],
      ),
    );
  }
}

class _ColumnView extends StatelessWidget {
  const _ColumnView({required this.column});

  final _KanbanColumn column;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 264,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ColumnHeader(column: column),
          const SizedBox(height: AppSpacing.s3),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final card in column.cards)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                    child: _CardView(card: card),
                  ),
                if (column.showDropPlaceholder) const _DropPlaceholder(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({required this.column});

  final _KanbanColumn column;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: column.dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.s2),
        Text(
          column.name.toUpperCase(),
          style: AppTypography.sm.copyWith(
            color: AppColors.textPrimary,
            fontWeight: AppTypography.weightSemibold,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: AppSpacing.s2),
        Text(
          '${column.cards.length}',
          style: AppTypography.mono(
            AppTypography.sm,
          ).copyWith(color: AppColors.textSecondary),
        ),
        const Spacer(),
        SizedBox(
          width: AppSpacing.minTouchTarget,
          height: AppSpacing.minTouchTarget,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () {},
            icon: const Icon(
              Icons.more_vert,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _CardView extends StatelessWidget {
  const _CardView({required this.card});

  final _KanbanCard card;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: AppRadius.lgRadius,
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.s5),
                child: Text(
                  card.title,
                  style: AppTypography.base.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: AppTypography.weightSemibold,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                card.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.sm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              _DocRefChip(label: card.docRef),
              const SizedBox(height: AppSpacing.s3),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: card.priority.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s1),
                  Text(
                    card.priority.label,
                    style: AppTypography.xs.copyWith(
                      color: card.priority.color,
                      fontWeight: AppTypography.weightMedium,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    card.issueId,
                    style: AppTypography.mono(
                      AppTypography.xs,
                    ).copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Positioned(
          top: AppSpacing.s2,
          right: AppSpacing.s2,
          child: Icon(
            Icons.drag_indicator,
            size: 16,
            color: AppColors.textDisabled,
          ),
        ),
      ],
    );
  }
}

/// Teal-outlined doc-reference pill in mono font — same visual language
/// as the Todo view's chip.
class _DocRefChip extends StatelessWidget {
  const _DocRefChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: AppColors.accentSecondary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.description_outlined,
            size: 12,
            color: AppColors.accentSecondary,
          ),
          const SizedBox(width: AppSpacing.s1),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.mono(
                AppTypography.xs,
              ).copyWith(color: AppColors.accentSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashed "Drop cards here" empty-state placeholder shown at the end of
/// a column, drawn with a small custom painter since no dashed-border
/// package is available in this project yet.
class _DropPlaceholder extends StatelessWidget {
  const _DropPlaceholder();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: AppColors.borderStrong,
        radius: AppRadius.lg,
      ),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 120),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 20, color: AppColors.textDisabled),
            const SizedBox(height: AppSpacing.s1),
            Text(
              'Drop cards here',
              style: AppTypography.sm.copyWith(
                color: AppColors.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dashWidth = 5.0;
  static const _dashGap = 4.0;
  static const _strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + _dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
