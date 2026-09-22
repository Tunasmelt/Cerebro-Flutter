import 'package:flutter/material.dart';

import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../../todo/presentation/todo_view.dart';
import 'kanban_view.dart';

enum _BoardTab { board, todo }

/// The "Board" shell screen: header + Board/Todo segmented toggle over
/// either [KanbanView] or [TodoView], matching the segmented control
/// shown in both mockups.
///
/// This screen is presentation-layer only (static mock data, no
/// backend) and is not yet wired into app navigation — that's a
/// separate milestone per phases-and-gates.md.
class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  _BoardTab _tab = _BoardTab.board;

  @override
  Widget build(BuildContext context) {
    final isBoard = _tab == _BoardTab.board;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      floatingActionButton: isBoard
          ? FloatingActionButton(
              backgroundColor: AppColors.accentPrimary,
              foregroundColor: AppColors.textOnAccent,
              onPressed: () {},
              child: const Icon(Icons.add),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s4,
                AppSpacing.s4,
                AppSpacing.s4,
                AppSpacing.s4,
              ),
              child: Column(
                children: [
                  _Header(isBoard: isBoard),
                  const SizedBox(height: AppSpacing.s4),
                  _SegmentedToggle(
                    tab: _tab,
                    onChanged: (tab) => setState(() => _tab = tab),
                  ),
                ],
              ),
            ),
            Expanded(child: isBoard ? const KanbanView() : const TodoView()),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isBoard});

  final bool isBoard;

  @override
  Widget build(BuildContext context) {
    final title = isBoard ? 'Research Board' : 'Tasks';
    final subtitleValue = isBoard ? '12' : '8';
    final subtitleLabel = isBoard ? 'cards' : 'open';
    final icon = isBoard ? Icons.dashboard_outlined : Icons.checklist_rounded;
    final trailingIcon = isBoard ? Icons.search : Icons.add;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accentPrimary,
            borderRadius: AppRadius.mdRadius,
          ),
          child: Icon(icon, color: AppColors.textOnAccent, size: 22),
        ),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.lg.copyWith(
                  color: AppColors.textPrimary,
                  fontFamily: AppTypography.fontFamilyDisplay,
                  fontWeight: AppTypography.weightSemibold,
                ),
              ),
              Row(
                children: [
                  Text(
                    subtitleValue,
                    style: AppTypography.mono(AppTypography.sm).copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s1),
                  Text(
                    subtitleLabel,
                    style: AppTypography.sm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _HeaderIconButton(icon: trailingIcon),
        const SizedBox(width: AppSpacing.s2),
        const _HeaderIconButton(icon: Icons.more_vert),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSpacing.minTouchTarget,
      height: AppSpacing.minTouchTarget,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderDefault),
          borderRadius: AppRadius.mdRadius,
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          onPressed: () {},
          icon: Icon(icon, color: AppColors.textPrimary, size: 20),
        ),
      ),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({required this.tab, required this.onChanged});

  final _BoardTab tab;
  final ValueChanged<_BoardTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.minTouchTarget,
      padding: const EdgeInsets.all(AppSpacing.s1),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          _SegmentButton(
            label: 'Board',
            icon: Icons.dashboard_outlined,
            selected: tab == _BoardTab.board,
            onTap: () => onChanged(_BoardTab.board),
          ),
          _SegmentButton(
            label: 'Todo',
            icon: Icons.checklist_rounded,
            selected: tab == _BoardTab.todo,
            onTap: () => onChanged(_BoardTab.todo),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: AppRadius.pillRadius,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentPrimary : Colors.transparent,
            borderRadius: AppRadius.pillRadius,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? AppColors.textOnAccent
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.s2),
              Text(
                label,
                style: AppTypography.base.copyWith(
                  color: selected
                      ? AppColors.textOnAccent
                      : AppColors.textSecondary,
                  fontWeight: AppTypography.weightSemibold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

