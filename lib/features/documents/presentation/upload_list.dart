import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../../../shared/widgets/error_view.dart';
import '../data/upload/upload_controller.dart';
import '../data/upload/upload_state.dart';

/// In-flight and just-failed uploads, above the document list. A
/// successful upload removes its own row once the real document shows up
/// in the list below.
class UploadList extends ConsumerWidget {
  const UploadList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploads = ref.watch(uploadsProvider);
    if (uploads.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        0,
        AppSpacing.s4,
        AppSpacing.s3,
      ),
      child: Column(
        key: const Key('upload_list'),
        children: [
          for (final item in uploads)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s2),
              child: _UploadRow(
                item: item,
                onDismiss: () =>
                    ref.read(uploadsProvider.notifier).dismiss(item.id),
              ),
            ),
        ],
      ),
    );
  }
}

String _stageLabel(UploadStage stage) {
  switch (stage) {
    case UploadStage.selecting:
      return 'Preparing';
    case UploadStage.uploading:
      return 'Uploading';
    case UploadStage.confirming:
      return 'Confirming';
    case UploadStage.done:
      return 'Done';
    case UploadStage.failed:
      return 'Failed';
  }
}

class _UploadRow extends StatelessWidget {
  const _UploadRow({required this.item, required this.onDismiss});

  final UploadItem item;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final failed = item.flow.stage == UploadStage.failed;

    return Container(
      key: Key('upload_row_${item.id}'),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(
          color: failed ? AppColors.danger : AppColors.borderDefault,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.base.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: AppTypography.weightMedium,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Text(
                _stageLabel(item.flow.stage),
                key: Key('upload_stage_${item.id}'),
                style: AppTypography.xs.copyWith(
                  color: failed ? AppColors.danger : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (!failed) ...[
            const SizedBox(height: AppSpacing.s2),
            LinearProgressIndicator(
              key: Key('upload_progress_${item.id}'),
              // Real progress while bytes go to Storage; indeterminate
              // for the other stages, which have no measurable length.
              value: item.flow.stage == UploadStage.uploading
                  ? item.progress
                  : null,
              backgroundColor: AppColors.borderSubtle,
              color: AppColors.accentPrimary,
            ),
          ],
          if (failed) ...[
            const SizedBox(height: AppSpacing.s2),
            ErrorView(
              exception: item.flow.error ?? const UnknownApiException(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: Key('upload_dismiss_${item.id}'),
                onPressed: onDismiss,
                child: const Text('Dismiss'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
