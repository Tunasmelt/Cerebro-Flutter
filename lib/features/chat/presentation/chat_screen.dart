import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../data/chat_controller.dart';
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

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      _followTail = position.maxScrollExtent - position.pixels < 80;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd({required bool force}) {
    if (!force && !_followTail) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _open(String documentId) {
    final open = widget.openDocument;
    if (open != null) {
      open(context, documentId);
    } else {
      context.push(AppRoutes.documentDetail(documentId));
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

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s4,
                AppSpacing.s6,
                AppSpacing.s2,
                AppSpacing.s2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chat',
                      style: AppTypography.xxxl.copyWith(
                        fontFamily: AppTypography.fontFamilyDisplay,
                        fontWeight: AppTypography.weightBold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (messages.isNotEmpty)
                    TextButton.icon(
                      key: const Key('chat_new'),
                      onPressed: controller.newChat,
                      icon: const Icon(Icons.add_comment_outlined, size: 18),
                      label: const Text('New chat'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: messages.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
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
                        );
                      },
                    ),
            ),
            ChatComposer(
              busy: chat.busy,
              onSend: (text) => controller.send(text),
              onStop: controller.stop,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
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
              style: AppTypography.sm.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
