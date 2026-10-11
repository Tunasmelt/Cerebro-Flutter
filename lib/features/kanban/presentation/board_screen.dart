import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app_routes.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_typography.dart';
import '../../../shared/widgets/error_view.dart';
import '../../documents/data/documents_list_notifier.dart';
import '../../todo/presentation/todo_view.dart';
import '../data/kanban_board.dart';
import '../data/kanban_controller.dart';
import 'create_card_dialog.dart';
import 'kanban_view.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';

class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});
  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  bool _todo = false;
  void _create(String column) => showDialog<void>(
    context: context,
    builder: (_) => CreateCardDialog(column: column),
  );
  Future<void> _delete(KanbanCard card) async {
    final controller = ref.read(kanbanControllerProvider.notifier);
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete card?',
      message: card.title,
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (confirmed && mounted) await controller.delete(card.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kanbanControllerProvider);
    final controller = ref.read(kanbanControllerProvider.notifier);
    final board = state.board;
    final documents = ref.watch(documentsListProvider).valueOrNull ?? [];
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      floatingActionButton: !_todo && board != null && board.columns.isNotEmpty
          ? FloatingActionButton(
              tooltip: 'Create card',
              onPressed: state.loading || state.saving
                  ? null
                  : () => _create(board.columns.first),
              child: const Icon(Icons.add),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.dashboard_outlined,
                        color: AppColors.accentPrimary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _todo ? 'Tasks' : board?.title ?? 'Board',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (!_todo && board != null)
                        Text(
                          '${board.cards.length} cards',
                          style: AppTypography.mono(AppTypography.sm),
                        ),
                      if (!_todo)
                        IconButton(
                          tooltip: 'Refresh board',
                          onPressed: state.loading || state.saving
                              ? null
                              : controller.reload,
                          icon: const Icon(Icons.refresh),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: AppColors.accentPrimary,
                      selectedForegroundColor: AppColors.textOnAccent,
                    ),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Board'),
                        icon: Icon(Icons.dashboard_outlined),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Todo'),
                        icon: Icon(Icons.checklist_rounded),
                      ),
                    ],
                    selected: {_todo},
                    onSelectionChanged: (selection) =>
                        setState(() => _todo = selection.single),
                  ),
                ],
              ),
            ),
            if (!_todo && (state.loading || state.saving))
              const LinearProgressIndicator(key: Key('kanban_busy')),
            if (!_todo && state.error != null)
              ErrorView(
                exception: state.error!,
                onRetry: state.saving || state.loading
                    ? null
                    : controller.reload,
              ),
            Expanded(
              child: _todo
                  ? const TodoView()
                  : board != null
                  ? KanbanView(
                      board: board,
                      saving: state.saving || state.loading,
                      documentTitles: {
                        for (final doc in documents) doc.id: doc.title,
                      },
                      onCreate: _create,
                      onMove: controller.move,
                      onDelete: _delete,
                      onOpenDocument: (id) =>
                          context.push(AppRoutes.documentDetail(id)),
                    )
                  : state.loading
                  ? const Center(child: CircularProgressIndicator())
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
