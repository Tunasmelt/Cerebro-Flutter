import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../../../shared/widgets/error_view.dart';
import '../data/document.dart';
import '../data/document_detail_provider.dart';
import '../data/ingest_retry_controller.dart';
import '../data/ingest_status.dart';
import 'document_presentation.dart';

class DocumentDetailScreen extends ConsumerWidget {
  const DocumentDetailScreen({super.key, required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(documentDetailProvider(documentId));

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        elevation: 0,
        title: const Text('Document'),
      ),
      body: SafeArea(
        top: false,
        child: detail.when(
          loading: () => const Center(
            key: Key('document_detail_loading'),
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => ErrorView(
            key: const Key('document_detail_error'),
            exception: error is AppException
                ? error
                : UnknownApiException(error.toString()),
            expanded: true,
            onRetry: () => ref.invalidate(documentDetailProvider(documentId)),
          ),
          data: (document) => _DocumentDetailBody(
            documentId: documentId,
            document: document,
            gaveUp: ref.watch(ingestPollGaveUpProvider(documentId)),
            onCheckAgain: () =>
                ref.invalidate(documentDetailProvider(documentId)),
          ),
        ),
      ),
    );
  }
}

class _DocumentDetailBody extends ConsumerWidget {
  const _DocumentDetailBody({
    required this.documentId,
    required this.document,
    required this.gaveUp,
    required this.onCheckAgain,
  });

  final String documentId;
  final DocumentDetail document;

  /// Polling stopped while the document was still processing.
  final bool gaveUp;
  final VoidCallback onCheckAgain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeColor = documentTypeColor(document.mime);
    // After a retry the backend still calls the document `failed` while
    // its job runs again; show what is actually happening.
    final status = effectiveDocumentStatus(document);
    final statusColor = documentStatusColor(status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        key: const Key('document_detail_body'),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s2,
                  vertical: AppSpacing.s1,
                ),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.smRadius,
                ),
                child: Text(
                  documentTypeLabel(document.mime),
                  style: AppTypography.mono(AppTypography.xs).copyWith(
                    color: typeColor,
                    fontWeight: AppTypography.weightSemibold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Text(
                  document.title,
                  style: AppTypography.lg.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: AppTypography.weightSemibold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s5),
          _DetailRow(
            label: 'Status',
            child: _StatusBadge(status: status, color: statusColor),
          ),
          _DetailRow(
            label: 'Size',
            child: Text(
              formatDocumentSize(document.sizeBytes),
              style: AppTypography.mono(
                AppTypography.sm,
              ).copyWith(color: AppColors.textPrimary),
            ),
          ),
          _DetailRow(
            label: 'Uploaded',
            child: Text(
              formatDocumentDate(document.createdAt),
              style: AppTypography.mono(
                AppTypography.sm,
              ).copyWith(color: AppColors.textPrimary),
            ),
          ),
          _IngestProgress(document: document, status: status, stalled: gaveUp),
          if (gaveUp && !isIngestSettled(document)) ...[
            Container(
              key: const Key('document_detail_stalled'),
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s3),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: AppRadius.mdRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "This is taking longer than usual. It's still being "
                    'processed on the server.',
                    style: AppTypography.xs.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextButton(
                    key: const Key('document_detail_check_again'),
                    onPressed: onCheckAgain,
                    child: const Text('Check again'),
                  ),
                ],
              ),
            ),
          ],
          if (status == DocumentStatus.failed) ...[
            const SizedBox(height: AppSpacing.s4),
            Container(
              key: const Key('document_detail_last_error'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s3,
                vertical: AppSpacing.s2,
              ),
              decoration: BoxDecoration(
                color: AppColors.dangerSubtle,
                borderRadius: AppRadius.mdRadius,
              ),
              child: Text(
                ingestErrorMessage(document.lastError),
                style: AppTypography.xs.copyWith(color: AppColors.dangerHover),
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
            if (ingestErrorRetryable(document.lastError))
              _RetryButton(documentId: documentId)
            else
              Text(
                'Upload the file again to try again.',
                key: const Key('document_detail_reupload_hint'),
                style: AppTypography.xs.copyWith(color: AppColors.textSecondary),
              ),
          ],
        ],
      ),
    );
  }
}

/// "Retry" for a failed document: asks the server to resume the job, then
/// the screen watches it run again. Disabled while the request is in
/// flight; a refusal is shown in plain words underneath.
class _RetryButton extends ConsumerWidget {
  const _RetryButton({required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final retry = ref.watch(retryIngestProvider(documentId));
    final error = retry.hasError ? retry.error : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          key: const Key('document_detail_retry'),
          onPressed: retry.isLoading
              ? null
              : () => ref.read(retryIngestProvider(documentId).notifier).retry(),
          icon: retry.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          label: Text(retry.isLoading ? 'Retrying…' : 'Retry'),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s2),
            child: Text(
              error is AppException ? error.message : "Couldn't retry.",
              key: const Key('document_detail_retry_error'),
              style: AppTypography.xs.copyWith(color: AppColors.dangerHover),
            ),
          ),
      ],
    );
  }
}

/// The ingest stage as it advances: a label, plus a bar while the
/// document is still being processed. Nothing for a document that has no
/// ingest job (null state) and is already settled.
class _IngestProgress extends StatelessWidget {
  const _IngestProgress({
    required this.document,
    required this.status,
    required this.stalled,
  });

  final DocumentDetail document;

  /// The effective status (a retried document's raw status still says
  /// failed while it runs).
  final DocumentStatus status;

  /// Nothing is polling any more, so don't show a bar that implies live
  /// progress.
  final bool stalled;

  @override
  Widget build(BuildContext context) {
    if (document.ingestState == null) return const SizedBox.shrink();
    final stage = IngestStage.fromApi(document.ingestState);
    final inProgress =
        !stage.isTerminal &&
        status == DocumentStatus.processing &&
        !stalled;

    return Column(
      key: const Key('document_detail_ingest'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailRow(
          label: 'Stage',
          child: Text(
            stage.label,
            key: const Key('document_detail_stage'),
            style: AppTypography.sm.copyWith(color: AppColors.textPrimary),
          ),
        ),
        if (inProgress)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s4),
            child: ClipRRect(
              borderRadius: AppRadius.pillRadius,
              child: LinearProgressIndicator(
                key: const Key('document_detail_progress'),
                value: stage.progress,
                minHeight: 4,
                backgroundColor: AppColors.bgElevated,
                color: AppColors.accentPrimary,
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTypography.sm.copyWith(color: AppColors.textSecondary),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});

  final DocumentStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillRadius,
      ),
      child: Text(
        documentStatusLabel(status),
        style: AppTypography.xs.copyWith(color: color),
      ),
    );
  }
}
