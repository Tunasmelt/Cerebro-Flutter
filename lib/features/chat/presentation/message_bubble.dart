import 'dart:math' as math;
import 'package:flutter/services.dart';
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
import '../../../shared/widgets/app_markdown.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../core/network/app_exception.dart';
import 'typing_indicator.dart';

/// One message in the conversation: the user's question, or an answer in
/// whatever state it is in (waiting, streaming, done, failed, stopped).
class ChatBubble extends ConsumerWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.canRetry,
    required this.onRetry,
    required this.onOpenDocument,
    this.onOpenCitation,
  });

  final ChatMessage message;

  /// This is the last answer and it failed, so "Try again" makes sense.
  final bool canRetry;
  final VoidCallback onRetry;
  final ValueChanged<String> onOpenDocument;
  final ValueChanged<ChipPart>? onOpenCitation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (message.role == ChatRole.user) return _UserBubble(message: message);
    return _AnswerBubble(
      message: message,
      canRetry: canRetry,
      onRetry: onRetry,
      onOpenDocument: onOpenDocument,
      onOpenCitation: onOpenCitation,
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
          maxWidth: math.min(680, MediaQuery.sizeOf(context).width * 0.82),
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
    this.onOpenCitation,
  });

  final ChatMessage message;
  final bool canRetry;
  final VoidCallback onRetry;
  final ValueChanged<String> onOpenDocument;
  final ValueChanged<ChipPart>? onOpenCitation;

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

    // A reopened answer carries the server's own title for each source, which
    // also proves the document existed. Otherwise fall back to the documents
    // list; null = list not loaded yet: assume the document exists.
    bool available(String documentId) =>
        message.citationTitles.containsKey(documentId) ||
        titles == null ||
        titles.containsKey(documentId);
    String titleOf(String documentId) =>
        titles?[documentId] ?? message.citationTitles[documentId] ?? 'Source';

    final hasText = parts.any((p) => p is TextPart && p.text.trim().isNotEmpty);

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(760, MediaQuery.sizeOf(context).width * 0.92),
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
              if (hasText) _markdown(parts, titleOf, available),
              if (hasText && !message.isStreaming)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    key: Key('chat_copy_${message.id}'),
                    tooltip: 'Copy answer',
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () async {
                      final text = parts
                          .map(
                            (part) => switch (part) {
                              TextPart(:final text) => text,
                              ChipPart(:final number) => '[$number]',
                            },
                          )
                          .join();
                      await Clipboard.setData(ClipboardData(text: text));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Answer copied')),
                        );
                      }
                    },
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
                        onTap: () {
                          final part = parts.whereType<ChipPart>().firstWhere(
                            (p) => p.documentId == source.documentId,
                          );
                          if (onOpenCitation != null) {
                            onOpenCitation!(part);
                          } else {
                            onOpenDocument(source.documentId);
                          }
                        },
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
                if (hasText) const Text('The answer above is incomplete.'),
              if (message.status == ChatMessageStatus.failed)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s3),
                  child: ErrorView(
                    retryKey: const Key('chat_retry'),
                    key: Key('chat_error_${message.id}'),
                    exception: message.error ?? const UnknownApiException(),
                    onRetry: canRetry ? onRetry : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _markdown(
    List<AnswerPart> parts,
    String Function(String) titleOf,
    bool Function(String) available,
  ) {
    var delimiter = '\uE000CEREBRO';
    final text = parts.whereType<TextPart>().map((part) => part.text).join();
    while (text.contains(delimiter)) {
      delimiter += '_';
    }
    final data = parts
        .map(
          (part) => switch (part) {
            TextPart(:final text) => text,
            ChipPart(:final number) => '$delimiter$number\uE001',
          },
        )
        .join();
    return AppMarkdown(
      data: data,
      delimiter: delimiter,
      inlineWidgets: {
        for (final part in parts.whereType<ChipPart>())
          part.number: CitationChip(
            key: Key('citation_chip_${part.number}'),
            number: part.number,
            title: titleOf(part.documentId),
            enabled: available(part.documentId),
            onTap: () {
              if (onOpenCitation != null) {
                onOpenCitation!(part);
              } else {
                onOpenDocument(part.documentId);
              }
            },
          ),
      },
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
  Widget build(BuildContext context) => TypingIndicator(label: label);
}
