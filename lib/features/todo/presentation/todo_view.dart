import 'package:flutter/material.dart';

import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';

/// Static mock data for the Todo list view (image 1 of the mockups).
/// No backend/networking exists yet — this is presentation-layer only.
class _TodoTask {
  const _TodoTask({
    required this.title,
    required this.timestamp,
    required this.docRef,
    this.sealed = false,
    this.completed = false,
  });

  final String title;
  final String timestamp;
  final String docRef;
  final bool sealed;
  final bool completed;
}

const _todayTasks = <_TodoTask>[
  _TodoTask(
    title: 'Review retrieval benchmark',
    timestamp: '10:00 UTC',
    docRef: 'doc:benchmarks §2.1',
  ),
  _TodoTask(
    title: 'Link architecture sources',
    timestamp: '14:00 UTC',
    docRef: 'doc:architecture-v3',
  ),
];

const _upcomingTasks = <_TodoTask>[
  _TodoTask(
    title: 'Test sealed document flow',
    timestamp: 'Apr 28',
    docRef: 'doc:security',
    sealed: true,
  ),
  _TodoTask(
    title: 'Refine graph clusters',
    timestamp: 'May 2',
    docRef: 'doc:graph-notes',
  ),
];

const _completedTasks = <_TodoTask>[
  _TodoTask(
    title: 'Set up development environment',
    timestamp: 'Apr 20',
    docRef: 'doc:dev-setup',
    completed: true,
  ),
  _TodoTask(
    title: 'Explore vector search alternatives',
    timestamp: 'Apr 18',
    docRef: 'doc:research',
    completed: true,
  ),
  _TodoTask(
    title: 'Draft onboarding checklist',
    timestamp: 'Apr 15',
    docRef: 'doc:onboarding',
    completed: true,
  ),
];

/// The "Todo" content view: TODAY / UPCOMING / COMPLETED sections, each
/// collapsible and showing a count, matching
/// `Mockups/011912f4-712e-4115-a3a8-a26627cc75f3.png`.
///
/// Static/mock local data only — this repo has no backend wiring yet.
class TodoView extends StatefulWidget {
  const TodoView({super.key});

  @override
  State<TodoView> createState() => _TodoViewState();
}

class _TodoViewState extends State<TodoView> {
  bool _todayExpanded = true;
  bool _upcomingExpanded = true;
  bool _completedExpanded = true;
  bool _showAllCompleted = false;

  @override
  Widget build(BuildContext context) {
    final visibleCompleted = _showAllCompleted
        ? _completedTasks
        : _completedTasks.take(2).toList();
    final hiddenCount = _completedTasks.length - visibleCompleted.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s4,
        AppSpacing.s4,
        AppSpacing.s8,
      ),
      children: [
        _SectionHeader(
          icon: Icons.calendar_today_outlined,
          label: 'TODAY',
          trailingLabel: '${_todayTasks.length} tasks',
          expanded: _todayExpanded,
          onTap: () => setState(() => _todayExpanded = !_todayExpanded),
        ),
        if (_todayExpanded) ...[
          const SizedBox(height: AppSpacing.s3),
          for (final task in _todayTasks) _TaskRowSpacer(task: task),
        ],
        const SizedBox(height: AppSpacing.s6),
        _SectionHeader(
          icon: Icons.access_time_rounded,
          label: 'UPCOMING',
          trailingLabel: '${_upcomingTasks.length} tasks',
          expanded: _upcomingExpanded,
          onTap: () => setState(() => _upcomingExpanded = !_upcomingExpanded),
        ),
        if (_upcomingExpanded) ...[
          const SizedBox(height: AppSpacing.s3),
          for (final task in _upcomingTasks) _TaskRowSpacer(task: task),
        ],
        const SizedBox(height: AppSpacing.s6),
        _CompletedSectionHeader(
          count: _completedTasks.length,
          expanded: _completedExpanded,
          onTap: () =>
              setState(() => _completedExpanded = !_completedExpanded),
        ),
        if (_completedExpanded) ...[
          const SizedBox(height: AppSpacing.s3),
          for (final task in visibleCompleted) _TaskRowSpacer(task: task),
          if (hiddenCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s1),
              child: InkWell(
                borderRadius: AppRadius.mdRadius,
                onTap: () => setState(() => _showAllCompleted = true),
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: AppSpacing.minTouchTarget,
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2,
                  ),
                  child: Text(
                    '+ $hiddenCount more completed '
                    '${hiddenCount == 1 ? 'task' : 'tasks'}',
                    style: AppTypography.sm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _TaskRowSpacer extends StatelessWidget {
  const _TaskRowSpacer({required this.task});

  final _TodoTask task;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s3),
      child: _TaskRow(task: task),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.trailingLabel,
    required this.expanded,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String trailingLabel;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.mdRadius,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: AppSpacing.minTouchTarget,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s1),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.s2),
            Text(
              label,
              style: AppTypography.sm.copyWith(
                color: AppColors.textSecondary,
                fontWeight: AppTypography.weightSemibold,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            Text(
              trailingLabel,
              style: AppTypography.mono(
                AppTypography.sm,
              ).copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.s1),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedSectionHeader extends StatelessWidget {
  const _CompletedSectionHeader({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.mdRadius,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: AppSpacing.minTouchTarget,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s1),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: AppColors.accentSuccess,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 14,
                color: AppColors.textOnAccent,
              ),
            ),
            const SizedBox(width: AppSpacing.s2),
            Text(
              'Completed',
              style: AppTypography.base.copyWith(
                color: AppColors.textPrimary,
                fontWeight: AppTypography.weightSemibold,
              ),
            ),
            const SizedBox(width: AppSpacing.s2),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s2,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.bgRaised,
                borderRadius: AppRadius.pillRadius,
              ),
              child: Text(
                '$count',
                style: AppTypography.mono(AppTypography.xs).copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: AppTypography.weightMedium,
                ),
              ),
            ),
            const Spacer(),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final _TodoTask task;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CheckCircle(completed: task.completed),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: AppTypography.base.copyWith(
                    color: task.completed
                        ? AppColors.textDisabled
                        : AppColors.textPrimary,
                    fontWeight: AppTypography.weightMedium,
                    decoration: task.completed
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: AppColors.textDisabled,
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                task.sealed
                    ? _LockChip(label: task.docRef)
                    : _DocRefChip(label: task.docRef),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                task.timestamp,
                style: AppTypography.mono(
                  AppTypography.sm,
                ).copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.s1),
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
          ),
        ],
      ),
    );
  }
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: completed
          ? Container(
              decoration: const BoxDecoration(
                color: AppColors.accentSuccess,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 15,
                color: AppColors.textOnAccent,
              ),
            )
          : Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderStrong, width: 1.5),
              ),
            ),
    );
  }
}

/// Teal-outlined doc-reference pill in mono font.
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
          Text(
            label,
            style: AppTypography.mono(
              AppTypography.xs,
            ).copyWith(color: AppColors.accentSecondary),
          ),
        ],
      ),
    );
  }
}

/// Amber-outlined lock pill for sealed tasks — amber is exclusive to
/// sealed/locked UI, never reused elsewhere on this screen.
class _LockChip extends StatelessWidget {
  const _LockChip({required this.label});

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
        border: Border.all(color: AppColors.accentLocked),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 12,
            color: AppColors.accentLocked,
          ),
          const SizedBox(width: AppSpacing.s1),
          Text(
            label,
            style: AppTypography.mono(
              AppTypography.xs,
            ).copyWith(color: AppColors.accentLocked),
          ),
        ],
      ),
    );
  }
}
