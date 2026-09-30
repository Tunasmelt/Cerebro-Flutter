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
          data: (document) => _DocumentDetailBody(document: document),
        ),
      ),
    );
  }
}

class _DocumentDetailBody extends StatelessWidget {
  const _DocumentDetailBody({required this.document});

  final DocumentDetail document;

  @override
  Widget build(BuildContext context) {
    final typeColor = documentTypeColor(document.mime);
    final statusColor = documentStatusColor(document.status);

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
          _DetailRow(label: 'Status', child: _StatusBadge(status: document.status, color: statusColor)),
          _DetailRow(
            label: 'Size',
            child: Text(
              formatDocumentSize(document.sizeBytes),
              style: AppTypography.mono(AppTypography.sm).copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _DetailRow(
            label: 'Uploaded',
            child: Text(
              formatDocumentDate(document.createdAt),
              style: AppTypography.mono(AppTypography.sm).copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (document.ingestState != null)
            _DetailRow(
              label: 'Ingest stage',
              child: Text(
                document.ingestState!,
                style: AppTypography.mono(AppTypography.sm).copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (document.lastError != null) ...[
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
                document.lastError!,
                style: AppTypography.xs.copyWith(color: AppColors.dangerHover),
              ),
            ),
          ],
        ],
      ),
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
