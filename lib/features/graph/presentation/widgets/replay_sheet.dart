import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/app_exception.dart';
import '../../../../shared/tokens/app_colors.dart';
import '../../../../shared/tokens/app_radius.dart';
import '../../../../shared/tokens/app_spacing.dart';
import '../../../../shared/tokens/app_typography.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../chat/data/chat_history_api.dart';
import '../../../chat/data/chat_sessions_list.dart';
import '../../../chat/presentation/conversation_date.dart';

/// Pick a past conversation to replay on the graph: its retrievals pulse the
/// documents they drew from, one answer at a time, in the order they happened.
class ReplaySheet extends ConsumerWidget {
  const ReplaySheet({super.key, required this.onSelect});

  final ValueChanged<ChatSessionSummary> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(chatSessionsListProvider);
    final height = MediaQuery.sizeOf(context).height * 0.55;
    return SizedBox(
      key: const Key('replay_sheet'),
      height: height,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s5,
                AppSpacing.s4,
                AppSpacing.s5,
                AppSpacing.s2,
              ),
              child: Text(
                'Replay a conversation',
                style: AppTypography.md.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: AppTypography.weightMedium,
                ),
              ),
            ),
            Expanded(
              child: sessions.when(
                loading: () => const Center(
                  key: Key('replay_loading'),
                  child: CircularProgressIndicator(),
                ),
                error: (error, _) => ErrorView(
                  key: const Key('replay_error'),
                  exception: error is AppException
                      ? error
                      : const UnknownApiException(),
                  expanded: true,
                  onRetry: ref.read(chatSessionsListProvider.notifier).refresh,
                ),
                data: (list) => list.isEmpty
                    ? const Center(
                        key: Key('replay_empty'),
                        child: Text(
                          'No conversations yet.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s3,
                          0,
                          AppSpacing.s3,
                          AppSpacing.s3,
                        ),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final s = list[i];
                          return ListTile(
                            key: Key('replay_${s.id}'),
                            minVerticalPadding: AppSpacing.s2,
                            title: Text(
                              s.preview ?? 'No question asked',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.base.copyWith(
                                color: s.preview == null
                                    ? AppColors.textDisabled
                                    : AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              formatConversationWhen(s.createdAt),
                              style: AppTypography.xs.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            onTap: () => onSelect(s),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
