import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app_routes.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../auth/data/current_user_provider.dart';
import '../../documents/data/documents_list_notifier.dart';
import '../data/todo_api.dart';
import '../data/todo_controller.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';

/// Colour and label for a task's priority. High is red, medium teal, low
/// grey; amber is reserved for sealed documents, so it is not used here.
({String label, Color color}) priorityStyle(TodoPriority priority) =>
    switch (priority) {
      TodoPriority.high => (label: 'High', color: AppColors.danger),
      TodoPriority.medium => (
        label: 'Medium',
        color: AppColors.accentSecondary,
      ),
      TodoPriority.low => (label: 'Low', color: AppColors.textSecondary),
    };

class TodoView extends ConsumerStatefulWidget {
  const TodoView({super.key});
  @override
  ConsumerState<TodoView> createState() => _TodoViewState();
}

class _TodoViewState extends ConsumerState<TodoView> {
  bool _completedOpen = false;
  TodoPriority? _priority;
  String? _owner;
  void _edit([TodoTask? task]) => showDialog<void>(
    context: context,
    builder: (_) => _TaskEditor(task: task),
  );
  Future<void> _delete(TodoTask task) async {
    final owner = ref.read(currentUserIdProvider);
    final accepted = await showAppConfirmDialog(
      context,
      title: 'Delete task?',
      message: task.title,
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (accepted && mounted && ref.read(currentUserIdProvider) == owner) {
      await ref.read(todoControllerProvider.notifier).delete(task.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(currentUserIdProvider);
    if (_owner != owner) {
      _owner = owner;
      _priority = null;
      _completedOpen = false;
    }
    final state = ref.watch(todoControllerProvider);
    final controller = ref.read(todoControllerProvider.notifier);
    final grouped = groupTodos(state.tasks ?? [], priority: _priority);
    final busy = state.loading || state.saving;
    final documents = ref.watch(documentsListProvider).valueOrNull ?? [];
    Widget row(TodoTask task) => Card(
      key: ValueKey('todo_task_${task.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: task.completed
                  ? 'Mark incomplete: ${task.title}'
                  : 'Mark complete: ${task.title}',
              child: Checkbox(
                key: ValueKey('todo_check_${task.id}'),
                value: task.completed,
                activeColor: AppColors.accentSuccess,
                onChanged: busy
                    ? null
                    : (value) => controller.setCompleted(task.id, value!),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      task.title,
                      style: AppTypography.base.copyWith(
                        decoration: task.completed
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.completed
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s1),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: StatusPill(
                        key: ValueKey('todo_priority_${task.id}'),
                        label: priorityStyle(task.priority).label,
                        color: priorityStyle(task.priority).color,
                      ),
                    ),
                  ),
                  if (task.documentId case final String id)
                    ActionChip(
                      label: Text(
                        documents
                                .where((doc) => doc.id == id)
                                .firstOrNull
                                ?.title ??
                            'Linked document',
                      ),
                      onPressed: () =>
                          context.push(AppRoutes.documentDetail(id)),
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              key: ValueKey('todo_actions_${task.id}'),
              tooltip: 'Task actions',
              enabled: !busy,
              onSelected: (action) =>
                  action == 'edit' ? _edit(task) : _delete(task),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit task')),
                PopupMenuItem(value: 'delete', child: Text('Delete task')),
              ],
            ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              FilledButton.icon(
                key: const Key('todo_add'),
                onPressed: busy || state.tasks == null ? null : () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text('Add task'),
              ),
              // The open-task count lives in the screen header, like the card
              // count on the Board tab.
              const Spacer(),
              IconButton(
                tooltip: 'Refresh tasks',
                onPressed: busy ? null : controller.reload,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selectedColor: AppColors.accentPrimarySubtle,
                  checkmarkColor: AppColors.accentPrimary,
                  selected: _priority == null,
                  onSelected: (_) => setState(() => _priority = null),
                ),
                for (final priority in TodoPriority.values)
                  ChoiceChip(
                    label: Text(priorityStyle(priority).label),
                    selectedColor: AppColors.accentPrimarySubtle,
                    checkmarkColor: AppColors.accentPrimary,
                    selected: _priority == priority,
                    onSelected: (_) => setState(() => _priority = priority),
                  ),
              ],
            ),
          ),
        ),
        if (busy) const LinearProgressIndicator(key: Key('todo_busy')),
        if (state.error != null)
          ErrorView(
            exception: state.error!,
            onRetry: busy ? null : controller.reload,
          ),
        Expanded(
          child: state.tasks == null
              ? state.loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.s4,
                        ),
                        child: AppSkeletonList(),
                      )
                    : const SizedBox.shrink()
              : ListView(
                  key: const Key('todo_list'),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    const Text('Active', style: AppTypography.lg),
                    if (grouped.active.isEmpty)
                      Padding(
                        key: const Key('todo_empty'),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.s8,
                          horizontal: AppSpacing.s4,
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.task_alt_rounded,
                              size: 32,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: AppSpacing.s3),
                            Text(
                              _priority == null
                                  ? 'No active tasks. Add one above.'
                                  : 'No ${_priority!.name}-priority active tasks.',
                              textAlign: TextAlign.center,
                              style: AppTypography.sm.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (final task in grouped.active) row(task),
                    if (grouped.completed.isNotEmpty) ...[
                      TextButton.icon(
                        key: const Key('todo_completed_toggle'),
                        onPressed: () =>
                            setState(() => _completedOpen = !_completedOpen),
                        icon: Icon(
                          _completedOpen
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                        label: Text(
                          'Completed (${grouped.completed.length})',
                          style: AppTypography.mono(AppTypography.sm),
                        ),
                      ),
                      if (_completedOpen)
                        for (final task in grouped.completed) row(task),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _TaskEditor extends ConsumerStatefulWidget {
  const _TaskEditor({this.task});
  final TodoTask? task;
  @override
  ConsumerState<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<_TaskEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late TodoPriority _priority;
  String? _owner;
  @override
  void initState() {
    super.initState();
    _owner = ref.read(currentUserIdProvider);
    _title = TextEditingController(text: widget.task?.title ?? '');
    _priority = widget.task?.priority ?? TodoPriority.medium;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() ||
        ref.read(currentUserIdProvider) != _owner) {
      return;
    }
    final success = await ref
        .read(todoControllerProvider.notifier)
        .save(_title.text, _priority, id: widget.task?.id);
    if (success && mounted && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(currentUserIdProvider);
    ref.listen(currentUserIdProvider, (_, next) {
      if (next != _owner && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context);
      }
    });
    final state = ref.watch(todoControllerProvider);
    if (owner != _owner) return const SizedBox.shrink();
    final busy = state.loading || state.saving;
    return AlertDialog(
      title: Text(widget.task == null ? 'Create task' : 'Edit task'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('todo_title'),
                  controller: _title,
                  autofocus: true,
                  enabled: !busy,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a title.'
                      : null,
                ),
                DropdownButtonFormField<TodoPriority>(
                  initialValue: _priority,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: [
                    for (final priority in TodoPriority.values)
                      DropdownMenuItem(
                        value: priority,
                        child: Text(priorityStyle(priority).label),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(() => _priority = value!),
                ),
                if (state.error != null) ErrorView(exception: state.error!),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('todo_save'),
          onPressed: busy ? null : _save,
          child: Text(state.saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
