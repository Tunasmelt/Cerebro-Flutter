import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/tokens/app_colors.dart';
import '../../../../shared/tokens/app_radius.dart';
import '../../../../shared/tokens/app_spacing.dart';
import '../../../../shared/tokens/app_typography.dart';
import '../../../chat/data/chat_controller.dart';
import '../../../chat/data/chat_message.dart';
import '../../../chat/presentation/message_bubble.dart';

/// The latest answer, shown over the graph so a question asked here can be
/// read while the documents it drew from pulse. It is the chat's own message
/// (same streaming, citations and retry), not a copy.
class GraphAnswerCard extends ConsumerWidget {
  const GraphAnswerCard({
    super.key,
    required this.onClose,
    required this.onOpenInChat,
    required this.onOpenDocument,
  });

  final VoidCallback onClose;
  final VoidCallback onOpenInChat;
  final ValueChanged<String> onOpenDocument;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatControllerProvider);
    final answer = chat.messages.isEmpty ? null : chat.messages.last;
    if (answer == null || answer.role != ChatRole.assistant) {
      return const SizedBox.shrink();
    }
    final maxHeight = MediaQuery.sizeOf(context).height * 0.38;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: DecoratedBox(
        key: const Key('graph_answer'),
        decoration: BoxDecoration(
          color: AppColors.bgElevated.withValues(alpha: 0.96),
          borderRadius: AppRadius.lgRadius,
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.s3,
                top: AppSpacing.s1,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Latest answer',
                      style: AppTypography.xs.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('graph_answer_open_chat'),
                    onPressed: onOpenInChat,
                    child: const Text('Open in Chat'),
                  ),
                  IconButton(
                    key: const Key('graph_answer_close'),
                    tooltip: 'Close',
                    onPressed: onClose,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s2,
                  0,
                  AppSpacing.s2,
                  AppSpacing.s2,
                ),
                child: ChatBubble(
                  message: answer,
                  canRetry: answer.status == ChatMessageStatus.failed,
                  onRetry: ref.read(chatControllerProvider.notifier).retry,
                  onOpenDocument: onOpenDocument,
                  onOpenCitation: (part) =>
                      context.push(AppRoutes.citationEvidence(part.chunkId)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
