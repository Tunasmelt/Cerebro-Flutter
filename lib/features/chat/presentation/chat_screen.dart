import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/network/app_exception.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/app_screen_header.dart';
import '../../../shared/tokens/app_motion.dart';
import '../data/document_titles_provider.dart';
import '../data/chat_controller.dart';
import '../data/chat_export_service.dart';
import '../data/chat_message.dart';
import 'chat_composer.dart';
import 'message_bubble.dart';

/// Ask a question about your documents and watch the answer stream in, with
/// numbered citation chips that open the documents it came from.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.openDocument});

  /// How a citation opens its source document. Defaults to the app router;
  /// overridable so the screen can be tested without one.
  final void Function(BuildContext context, String documentId)? openDocument;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scroll = ScrollController();

  /// Whether the list was at (or near) the bottom before the latest update —
  /// if the user has scrolled up to re-read something, a streaming answer
  /// must not drag them back down.
  bool _followTail = true;
  bool _autoScrolling = false;
  bool _scrollScheduled = false;

  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      if (_autoScrolling) return;
      final follow = position.maxScrollExtent - position.pixels < 80;
      if (follow != _followTail) setState(() => _followTail = follow);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd({required bool force}) {
    if (!mounted || (!force && !_followTail)) return;
    if (force) _followTail = true;
    if (_scrollScheduled || _autoScrolling) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _scrollScheduled = false;
      if (!mounted || !_scroll.hasClients || !_followTail) return;
      final end = _scroll.position.maxScrollExtent;
      if ((end - _scroll.offset).abs() < 1) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(end);
        return;
      }
      _autoScrolling = true;
      try {
        await _scroll.animateTo(
          end,
          duration: AppMotion.base,
          curve: AppMotion.soft,
        );
      } finally {
        _autoScrolling = false;
        if (mounted && _followTail) _scrollToEnd(force: false);
      }
    });
  }

  void _open(String documentId) {
    final open = widget.openDocument;
    if (open != null) {
      open(context, documentId);
    } else {
      context.push(AppRoutes.documentPreview(documentId));
    }
  }

  void _openHistory() => context.push(AppRoutes.chatHistory);

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await ref.read(chatExportServiceProvider).exportOpenConversation();
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              key: const Key('chat_export_error'),
              content: Text(e.message),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);

    ref.listen<ChatState>(chatControllerProvider, (previous, next) {
      final grew = next.messages.length > (previous?.messages.length ?? 0);
      // A new question always scrolls into view; a streaming answer only
      // follows if the user is already at the bottom.
      _scrollToEnd(force: grew);
    });

    final messages = chat.messages;
    final hasConversation = messages.isNotEmpty || chat.sessionId != null;
    final canExport =
        chat.sessionId != null &&
        messages.isNotEmpty &&
        !chat.busy &&
        !chat.loading;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppScreenHeader(
              title: 'Chat',
              actions: [
                if (canExport)
                  IconButton(
                    key: const Key('chat_export'),
                    tooltip: 'Export as Markdown',
                    onPressed: _exporting ? null : _export,
                    icon: const Icon(Icons.ios_share_outlined),
                  ),
                IconButton(
                  key: const Key('chat_history'),
                  tooltip: 'Conversations',
                  onPressed: _openHistory,
                  icon: const Icon(Icons.history),
                ),
                if (hasConversation)
                  IconButton(
                    key: const Key('chat_new'),
                    tooltip: 'New chat',
                    onPressed: controller.newChat,
                    icon: const Icon(Icons.add_comment_outlined),
                  ),
              ],
            ),
            if (chat.documentTitle != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chatting about ${chat.documentTitle}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  chat.loading
                      ? const Center(
                          key: Key('chat_loading'),
                          child: CircularProgressIndicator(),
                        )
                      : chat.loadError != null
                      ? ErrorView(
                          key: const Key('chat_load_error'),
                          exception: chat.loadError!,
                          expanded: true,
                          onRetry: chat.loadError is RequestRejectedException
                              ? null
                              : controller.reloadHistory,
                        )
                      : messages.isEmpty
                      ? _EmptyState(onPrompt: controller.send)
                      : NotificationListener<UserScrollNotification>(
                          onNotification: (notification) {
                            if (notification.direction !=
                                ScrollDirection.idle) {
                              _autoScrolling = false;
                              final follow =
                                  _scroll.position.maxScrollExtent -
                                      _scroll.offset <
                                  80;
                              if (_followTail != follow) {
                                setState(() => _followTail = follow);
                              }
                            }
                            return false;
                          },
                          child: ListView.separated(
                            key: const Key('chat_messages'),
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.s4,
                              AppSpacing.s2,
                              AppSpacing.s4,
                              AppSpacing.s4,
                            ),
                            itemCount: messages.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.s3),
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              return ChatBubble(
                                message: message,
                                canRetry:
                                    index == messages.length - 1 &&
                                    message.status == ChatMessageStatus.failed,
                                onRetry: controller.retry,
                                onOpenDocument: _open,
                                onOpenCitation: (part) {
                                  if (widget.openDocument != null) {
                                    _open(part.documentId);
                                  } else {
                                    context.push(
                                      AppRoutes.citationEvidence(part.chunkId),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ),
                  if (!_followTail && messages.isNotEmpty)
                    Positioned(
                      bottom: 12,
                      right: 16,
                      child: FilledButton.icon(
                        key: const Key('chat_jump_latest'),
                        onPressed: () {
                          setState(() => _followTail = true);
                          _scrollToEnd(force: true);
                        },
                        icon: const Icon(Icons.arrow_downward),
                        label: const Text('Latest'),
                      ),
                    ),
                ],
              ),
            ),
            ChatComposer(
              busy: chat.busy,
              enabled: !chat.loading && chat.loadError == null,
              onSend: (text) => controller.send(text),
              onStop: controller.stop,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.onPrompt});
  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titles =
        ref.watch(documentTitlesProvider)?.values.take(3).toList() ??
        <String>[];
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s8),
          child: Column(
            key: const Key('chat_empty'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                size: 40,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: AppSpacing.s3),
              Text(
                'Ask your documents',
                style: AppTypography.lg.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                'Answers are drawn from what you have uploaded, with sources '
                'you can open.',
                textAlign: TextAlign.center,
                style: AppTypography.sm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (titles.isNotEmpty) const SizedBox(height: AppSpacing.s4),
              // Outlined, full-width, left-aligned: they read as tappable
              // suggestions rather than loose lines of coloured text.
              for (final title in titles)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s2),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s3,
                          vertical: AppSpacing.s3,
                        ),
                      ),
                      onPressed: () =>
                          onPrompt('Summarize the key points in "$title".'),
                      icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                      label: Text(
                        'Summarize $title',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
