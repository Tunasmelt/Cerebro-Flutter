import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/network/app_exception.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_screen_header.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../auth/data/current_user_provider.dart';
import '../data/document.dart';
import '../data/documents_list_notifier.dart';
import '../data/ingest_status.dart';
import '../data/upload/upload_controller.dart';
import '../data/upload/upload_picker.dart';
import 'document_presentation.dart';
import 'upload_list.dart';
import 'upload_source_sheet.dart';

/// Real Documents list against `GET /api/v1/documents` (Milestone 2.1)
/// with the upload entry point (Milestone 2.2): the Add button opens a
/// source sheet (file / photo library / camera), and in-flight uploads
/// appear above the list. Once there are documents, a title search and
/// status chips narrow the list.
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  late final AppLifecycleListener _lifecycle;
  bool _refreshingOnResume = false;
  final _search = TextEditingController();
  DocumentFilter _filter = DocumentFilter.all;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refreshOnResume);
  }

  Future<void> _refreshOnResume() async {
    if (_refreshingOnResume || ref.read(currentUserIdProvider) == null) return;
    _refreshingOnResume = true;
    try {
      // The upload or ingest may have finished while Android suspended us.
      // Refresh also restarts an exhausted ingest polling window.
      await ref.read(documentsListProvider.notifier).refresh();
    } finally {
      _refreshingOnResume = false;
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _onAddPressed(BuildContext context, WidgetRef ref) async {
    final source = await showUploadSourceSheet(context);
    if (source == null || !context.mounted) return;

    try {
      final picked = await ref.read(uploadPickerProvider).pick(source);
      // The picker (the camera especially) can stay open a long time. If
      // this screen is gone by then — the session ended and the router moved
      // on — drop the result: touching `ref` now would throw, and starting
      // the upload anyway could send it under whoever signs in next.
      if (picked == null || !context.mounted) return;
      // Not awaited on purpose: the flow reports through `uploadsProvider`,
      // and the user shouldn't be held on this handler while it runs.
      ref.read(uploadsProvider.notifier).upload(picked);
    } on UploadPickException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(key: const Key('upload_pick_error'), content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(documentsListProvider);
    final notifier = ref.read(documentsListProvider.notifier);
    final loaded = documents.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      floatingActionButton: FloatingActionButton(
        key: const Key('documents_add_fab'),
        backgroundColor: AppColors.accentPrimary,
        foregroundColor: AppColors.textOnAccent,
        tooltip: 'Add a document',
        onPressed: () => _onAddPressed(context, ref),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppScreenHeader(
              title: 'Documents',
              subtitle: loaded == null || loaded.isEmpty
                  ? null
                  : '${loaded.length} '
                        '${loaded.length == 1 ? 'document' : 'documents'}',
            ),
            const UploadList(),
            if (loaded != null && loaded.isNotEmpty)
              _SearchAndFilters(
                controller: _search,
                filter: _filter,
                onQuery: (_) => setState(() {}),
                onFilter: (f) => setState(() => _filter = f),
              ),
            Expanded(
              child: documents.when(
                loading: () => const Padding(
                  key: Key('documents_loading'),
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                  child: AppSkeletonList(),
                ),
                error: (error, _) => ErrorView(
                  key: const Key('documents_error'),
                  exception: error is AppException
                      ? error
                      : UnknownApiException(error.toString()),
                  expanded: true,
                  onRetry: notifier.refresh,
                ),
                data: (docs) {
                  final shown = filterDocuments(
                    docs,
                    query: _search.text,
                    filter: _filter,
                    now: DateTime.now(),
                  );
                  return RefreshIndicator(
                    onRefresh: notifier.refresh,
                    child: docs.isEmpty
                        ? AppEmptyState(
                            key: const Key('documents_empty'),
                            icon: Icons.description_outlined,
                            title: 'No documents yet.',
                            message:
                                'Add a PDF, a note or a photo and Cerebro '
                                'will make it searchable.',
                            actionLabel: 'Add a document',
                            onAction: () => _onAddPressed(context, ref),
                          )
                        : shown.isEmpty
                        ? AppEmptyState(
                            key: const Key('documents_no_match'),
                            icon: Icons.search_off_rounded,
                            title: 'Nothing matches.',
                            message: 'Try a different word or filter.',
                            actionLabel: 'Clear filters',
                            onAction: () => setState(() {
                              _search.clear();
                              _filter = DocumentFilter.all;
                            }),
                          )
                        : ListView.separated(
                            key: const Key('documents_list'),
                            // Room under the last row for the floating add
                            // button: its height plus the margin around it.
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.s4,
                              0,
                              AppSpacing.s4,
                              56 + 2 * kFloatingActionButtonMargin,
                            ),
                            itemCount: shown.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.s2),
                            itemBuilder: (context, index) =>
                                _DocumentRow(document: shown[index]),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.filter,
    required this.onQuery,
    required this.onFilter,
  });

  final TextEditingController controller;
  final DocumentFilter filter;
  final ValueChanged<String> onQuery;
  final ValueChanged<DocumentFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4,
            0,
            AppSpacing.s4,
            AppSpacing.s2,
          ),
          child: TextField(
            key: const Key('documents_search'),
            controller: controller,
            onChanged: onQuery,
            textInputAction: TextInputAction.search,
            style: AppTypography.sm.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search documents',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      key: const Key('documents_search_clear'),
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () {
                        controller.clear();
                        onQuery('');
                      },
                    ),
            ),
          ),
        ),
        SizedBox(
          height: AppSpacing.minTouchTarget,
          child: ListView.separated(
            key: const Key('documents_filters'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            itemCount: DocumentFilter.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s2),
            itemBuilder: (context, i) {
              final f = DocumentFilter.values[i];
              return Center(
                child: ChoiceChip(
                  key: Key('documents_filter_${f.name}'),
                  label: Text(f.label),
                  selected: f == filter,
                  onSelected: (_) => onFilter(f),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
      ],
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.document});

  final DocumentSummary document;

  @override
  Widget build(BuildContext context) {
    final typeColor = documentTypeColor(document.mime);
    final abandoned = summaryIsAbandonedUpload(document, DateTime.now());
    final statusColor = abandoned
        ? AppColors.danger
        : documentStatusColor(document.status);

    return Material(
      color: AppColors.bgElevated,
      borderRadius: AppRadius.lgRadius,
      child: InkWell(
        key: Key('document_row_${document.id}'),
        borderRadius: AppRadius.lgRadius,
        onTap: () => context.push(
          document.status == DocumentStatus.sealed
              ? AppRoutes.documentDetail(document.id)
              : AppRoutes.documentPreview(document.id),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderDefault),
            borderRadius: AppRadius.lgRadius,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
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
                      style: AppTypography.mono(
                        AppTypography.xs,
                      ).copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              StatusPill(
                label: abandoned
                    ? 'Incomplete'
                    : documentStatusLabel(document.status),
                color: statusColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
