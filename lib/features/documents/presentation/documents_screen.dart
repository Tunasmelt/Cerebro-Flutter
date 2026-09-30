import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/network/app_exception.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../../../shared/widgets/error_view.dart';
import '../data/document.dart';
import '../data/documents_list_notifier.dart';
import 'document_presentation.dart';

/// Milestone 2.1 — real Documents list against `GET /api/v1/documents`.
/// Upload (Milestone 2.2) doesn't exist yet, so this screen is
/// read-only: no dropzone, no upload button.
class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(documentsListProvider);
    final notifier = ref.read(documentsListProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s4,
                AppSpacing.s6,
                AppSpacing.s4,
                AppSpacing.s4,
              ),
              child: Text(
                'Documents',
                style: AppTypography.xxxl.copyWith(
                  fontFamily: AppTypography.fontFamilyDisplay,
                  fontWeight: AppTypography.weightBold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: documents.when(
                loading: () => const Center(
                  key: Key('documents_loading'),
                  child: CircularProgressIndicator(),
                ),
                error: (error, _) => ErrorView(
                  key: const Key('documents_error'),
                  exception: error is AppException
                      ? error
                      : UnknownApiException(error.toString()),
                  expanded: true,
                  onRetry: notifier.refresh,
                ),
                data: (docs) => RefreshIndicator(
                  onRefresh: notifier.refresh,
                  child: docs.isEmpty
                      ? ListView(
                          // A scrollable single child, not a bare Center:
                          // RefreshIndicator needs a scrollable
                          // descendant to trigger from, even when the
                          // empty state itself doesn't scroll.
                          children: const [
                            SizedBox(height: AppSpacing.s16),
                            Center(
                              key: Key('documents_empty'),
                              child: Text(
                                'No documents yet.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          key: const Key('documents_list'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s4,
                          ),
                          itemCount: docs.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.s2),
                          itemBuilder: (context, index) =>
                              _DocumentRow(document: docs[index]),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.document});

  final DocumentSummary document;

  @override
  Widget build(BuildContext context) {
    final typeColor = documentTypeColor(document.mime);
    final statusColor = documentStatusColor(document.status);

    return Material(
      color: AppColors.bgElevated,
      borderRadius: AppRadius.lgRadius,
      child: InkWell(
        key: Key('document_row_${document.id}'),
        borderRadius: AppRadius.lgRadius,
        onTap: () => context.push(AppRoutes.documentDetail(document.id)),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderDefault),
            borderRadius: AppRadius.lgRadius,
          ),
          child: Row(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      document.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.base.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: AppTypography.weightMedium,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      '${formatDocumentSize(document.sizeBytes)} · '
                      '${formatDocumentDate(document.createdAt)}',
                      style: AppTypography.mono(AppTypography.xs).copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s2,
                  vertical: AppSpacing.s1,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.pillRadius,
                ),
                child: Text(
                  documentStatusLabel(document.status),
                  style: AppTypography.xs.copyWith(color: statusColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
