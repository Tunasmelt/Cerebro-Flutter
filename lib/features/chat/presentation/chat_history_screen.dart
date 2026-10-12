import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../../../shared/widgets/error_view.dart';
import '../data/chat_controller.dart';
import '../data/pending_session_deletes.dart';
import '../../auth/data/current_user_provider.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../data/chat_export_service.dart';
import '../data/chat_history_api.dart';
import '../data/chat_sessions_list.dart';
import 'conversation_date.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';

enum _SessionAction { export, delete }

/// Past conversations: open one, export it to Markdown, or delete it.
class ChatHistoryScreen extends ConsumerStatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  ConsumerState<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends ConsumerState<ChatHistoryScreen> {
  /// Conversations being exported or deleted right now (one at a time each).
  final Set<String> _working = {};

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('chat_history_message'),
          content: Text(message),
        ),
      );
  }

  void _open(ChatSessionSummary session) {
    ref.read(chatControllerProvider.notifier).openSession(session);
    Navigator.of(context).maybePop();
  }

  Future<void> _export(ChatSessionSummary session) async {
    if (_working.contains(session.id)) return;
    setState(() => _working.add(session.id));
    try {
      await ref.read(chatExportServiceProvider).exportSession(session);
    } on AppException catch (e) {
      if (mounted) _say(e.message);
    } finally {
      if (mounted) setState(() => _working.remove(session.id));
    }
  }

  Future<void> _delete(ChatSessionSummary session) async {
    if (_working.contains(session.id)) return;
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete this conversation?',
      message:
          "The conversation and its messages will be removed. This can't be "
          'undone.',
      confirmLabel: 'Delete',
      destructive: true,
      confirmKey: const Key('chat_delete_confirm'),
      cancelKey: const Key('chat_delete_cancel'),
    );
    if (!confirmed || !mounted) return;

    setState(() => _working.add(session.id));
    final error = await ref
        .read(chatSessionsListProvider.notifier)
        .delete(session.id);
    if (!mounted) return;
    setState(() => _working.remove(session.id));
    if (error != null) _say(error.message);
  }

  String _dateGroup(DateTime value) {
    final now = DateTime.now();
    final local = value.toLocal();
    final date = DateTime(local.year, local.month, local.day);
    final today = DateTime(now.year, now.month, now.day);
    if (date == today) return 'Today';
    if (date == DateTime(now.year, now.month, now.day - 1)) return 'Yesterday';
    return 'Earlier';
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(chatSessionsListProvider);
    final pending = ref.watch(pendingSessionDeletesProvider);
    ref.listen(pendingSessionDeletesProvider, (_, next) {
      if (next.error != null && mounted) _say(next.error!.message);
    });
    final notifier = ref.read(chatSessionsListProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        elevation: 0,
        title: const Text('Conversations'),
      ),
      body: SafeArea(
        top: false,
        child: sessions.when(
          skipLoadingOnReload: false,
          loading: () => const Center(
            key: Key('chat_history_loading'),
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => ErrorView(
            key: const Key('chat_history_error'),
            exception: error is AppException
                ? error
                : const UnknownApiException(),
            expanded: true,
            onRetry: notifier.refresh,
          ),
          data: (all) {
            final list =
                all
                    .where((session) => !pending.ids.contains(session.id))
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return RefreshIndicator(
              onRefresh: notifier.refresh,
              child: list.isEmpty
                  ? const AppEmptyState(
                      key: Key('chat_history_empty'),
                      icon: Icons.history,
                      title: 'No conversations yet',
                      message:
                          'Ask a question in Chat and it will appear here.',
                    )
                  : ListView.separated(
                      key: const Key('chat_history_list'),
                      padding: const EdgeInsets.all(AppSpacing.s4),
                      itemCount: list.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.s2),
                      itemBuilder: (context, index) {
                        final session = list[index];
                        final group = _dateGroup(session.createdAt);
                        return Dismissible(
                          key: Key('chat_swipe_${session.id}'),
                          direction: _working.contains(session.id)
                              ? DismissDirection.none
                              : DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.all(16),
                            color: AppColors.dangerSubtle,
                            child: const Icon(
                              Icons.delete_outline,
                              color: AppColors.danger,
                            ),
                          ),
                          onDismissed: (_) {
                            final owner = ref.read(currentUserIdProvider);
                            ref
                                .read(pendingSessionDeletesProvider.notifier)
                                .queue(session.id);
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: const Text('Conversation removed'),
                                  duration: const Duration(seconds: 5),
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    onPressed: () {
                                      if (mounted &&
                                          ref.read(currentUserIdProvider) ==
                                              owner) {
                                        ref
                                            .read(
                                              pendingSessionDeletesProvider
                                                  .notifier,
                                            )
                                            .undo(session.id);
                                      }
                                    },
                                  ),
                                ),
                              );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (index == 0 ||
                                  _dateGroup(list[index - 1].createdAt) !=
                                      group)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: AppSectionHeader(group),
                                ),
                              _SessionTile(
                                session: session,
                                working: _working.contains(session.id),
                                onOpen: () => _open(session),
                                onAction: (action) => switch (action) {
                                  _SessionAction.export => _export(session),
                                  _SessionAction.delete => _delete(session),
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.working,
    required this.onOpen,
    required this.onAction,
  });

  final ChatSessionSummary session;
  final bool working;
  final VoidCallback onOpen;
  final ValueChanged<_SessionAction> onAction;

  @override
  Widget build(BuildContext context) {
    final hasPreview = session.preview != null;
    return Material(
      color: AppColors.bgElevated,
      borderRadius: AppRadius.lgRadius,
      child: InkWell(
        key: Key('chat_session_${session.id}'),
        borderRadius: AppRadius.lgRadius,
        onTap: working ? null : onOpen,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.only(
            left: AppSpacing.s4,
            top: AppSpacing.s3,
            bottom: AppSpacing.s3,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgRadius,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasPreview ? session.preview! : 'No question asked',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.base.copyWith(
                        color: hasPreview
                            ? AppColors.textPrimary
                            : AppColors.textDisabled,
                        fontStyle: hasPreview
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatConversationWhen(session.createdAt),
                      style: AppTypography.xs.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (working)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.s3),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                PopupMenuButton<_SessionAction>(
                  key: Key('chat_session_menu_${session.id}'),
                  tooltip: 'Conversation options',
                  color: AppColors.bgRaised,
                  onSelected: onAction,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      key: Key('chat_session_export'),
                      value: _SessionAction.export,
                      child: Text('Export as Markdown'),
                    ),
                    PopupMenuItem(
                      key: const Key('chat_session_delete'),
                      value: _SessionAction.delete,
                      child: Text(
                        'Delete',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
