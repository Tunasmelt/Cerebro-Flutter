import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../data/answer_segments.dart';
import '../data/chat_message.dart';
import '../data/document_titles_provider.dart';
import '../data/resolved_answer.dart';
import 'citation_chip.dart';

/// One message in the conversation: the user's question, or an answer in
/// whatever state it is in (waiting, streaming, done, failed, stopped).
class ChatBubble extends ConsumerWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.canRetry,
    required this.onRetry,
    required this.onOpenDocument,
  });

  final ChatMessage message;

  /// This is the last answer and it failed, so "Try again" makes sense.
  final bool canRetry;
  final VoidCallback onRetry;
  final ValueChanged<String> onOpenDocument;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (message.role == ChatRole.user) return _UserBubble(message: message);
    return _AnswerBubble(
      message: message,
      canRetry: canRetry,
      onRetry: onRetry,
      onOpenDocument: onOpenDocument,
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Container(
          key: Key('chat_user_${message.id}'),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s3,
          ),
          decoration: BoxDecoration(
            color: AppColors.accentPrimarySubtle,
            borderRadius: AppRadius.lgRadius,
            border: Border.all(color: AppColors.accentPrimaryBorder),
          ),
          child: SelectableText(
            message.text,
            style: AppTypography.base.copyWith(color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _AnswerBubble extends ConsumerWidget {
  const _AnswerBubble({
    required this.message,
    required this.canRetry,
    required this.onRetry,
    required this.onOpenDocument,
  });

  final ChatMessage message;
  final bool canRetry;
  final VoidCallback onRetry;
  final ValueChanged<String> onOpenDocument;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Never draw message.text directly: it still holds raw [[chunk:…]]
    // markers. Parse them out, and keep only the ones the server backs.
    final parts = resolveAnswer(
      parseAnswerSegments(message.text, streaming: message.isStreaming),
      retrievedChunkIds: message.retrievedChunkIds,
      citedDocuments: message.citedDocuments,
    );
    final titles = ref.watch(documentTitlesProvider);
    final sources = sourcesOf(parts);

    // null = list not loaded yet: assume the document exists.
    bool available(String documentId) =>
        titles == null || titles.containsKey(documentId);
    String titleOf(String documentId) => titles?[documentId] ?? 'Source';

    final hasText = parts.any((p) => p is TextPart && p.text.trim().isNotEmpty);

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.92,
        ),
        child: Container(
          key: Key('chat_answer_${message.id}'),
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: AppRadius.lgRadius,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.retrievalFoundNothing)
                _NoMatches(key: Key('chat_no_matches_${message.id}')),
              if (message.isStreaming && !hasText)
                _Thinking(
                  key: Key('chat_thinking_${message.id}'),
                  label: message.retrievalDone
                      ? 'Writing the answer…'
                      : 'Searching your documents…',
                ),
              if (hasText)
                SelectionArea(
                  child: Text.rich(
                    TextSpan(
                      style: AppTypography.base.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                      children: [
                        for (final part in parts)
                          switch (part) {
                            TextPart(:final text) => TextSpan(text: text),
                            ChipPart() => WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: CitationChip(
                                key: Key('citation_chip_${part.number}'),
                                number: part.number,
                                title: titleOf(part.documentId),
                                enabled: available(part.documentId),
                                onTap: () => onOpenDocument(part.documentId),
                              ),
                            ),
                          },
                      ],
                    ),
                  ),
                ),
              if (sources.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s3),
                Wrap(
                  key: Key('chat_sources_${message.id}'),
                  spacing: AppSpacing.s2,
                  runSpacing: AppSpacing.s2,
                  children: [
                    for (final source in sources)
                      SourceChip(
                        key: Key('source_chip_${source.documentId}'),
                        title: titleOf(source.documentId),
                        numbers: source.numbers,
                        enabled: available(source.documentId),
                        onTap: () => onOpenDocument(source.documentId),
                      ),
                  ],
                ),
              ],
              if (message.status == ChatMessageStatus.stopped)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s2),
                  child: Text(
                    hasText ? 'Stopped' : 'Stopped before an answer arrived',
                    key: Key('chat_stopped_${message.id}'),
                    style: AppTypography.xs.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              if (message.status == ChatMessageStatus.failed)
                _Failure(
                  key: Key('chat_error_${message.id}'),
                  message: message.error?.message ?? 'Something went wrong.',
                  partial: hasText,
                  canRetry: canRetry,
                  onRetry: onRetry,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when retrieval ran and found nothing: the answer that follows is
/// not grounded in the user's documents, and must not look like one that is.
class _NoMatches extends StatelessWidget {
  const _NoMatches({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.s3),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: AppColors.accentSecondarySubtle,
        borderRadius: AppRadius.mdRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 18,
            color: AppColors.accentSecondary,
          ),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No matching documents',
                  style: AppTypography.sm.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: AppTypography.weightSemibold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Nothing in your documents matched this question, so what "
                  "follows isn't based on them.",
                  style: AppTypography.xs.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accentPrimary,
          ),
        ),
        const SizedBox(width: AppSpacing.s2),
        Text(
          label,
          style: AppTypography.sm.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({
    super.key,
    required this.message,
    required this.partial,
    required this.canRetry,
    required this.onRetry,
  });

  final String message;
  final bool partial;
  final bool canRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.s3),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: AppColors.dangerSubtle,
        borderRadius: AppRadius.mdRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            partial ? '$message The answer above is incomplete.' : message,
            style: AppTypography.sm.copyWith(color: AppColors.dangerHover),
          ),
          if (canRetry)
            TextButton.icon(
              key: const Key('chat_retry'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, AppSpacing.minTouchTarget),
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
        ],
      ),
    );
  }
}
