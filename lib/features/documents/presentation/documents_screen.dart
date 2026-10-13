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
import 'document_actions_sheet.dart';
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
  bool _searching = false;

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
    final choice = await showUploadSourceSheet(context);
    if (choice == null || !context.mounted) return;
    if (choice is AddNote) {
      final saved = await context.push<bool>(AppRoutes.newNote);
      if (saved == true && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              key: Key('note_saved_message'),
              content: Text('Note saved. It will be ready in a moment.'),
            ),
          );
      }
      return;
    }
    final source = (choice as AddFromSource).source;

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
              actions: [
                if (loaded != null && loaded.isNotEmpty)
                  IconButton(
                    key: const Key('documents_search_toggle'),
                    tooltip: _searching ? 'Close search' : 'Search documents',
                    icon: Icon(
                      _searching ? Icons.close_rounded : Icons.search_rounded,
                    ),
                    onPressed: () => setState(() {
                      if (_searching) _search.clear();
                      _searching = !_searching;
                    }),
                  ),
              ],
            ),
            const UploadList(),
            if (loaded != null && loaded.isNotEmpty)
              _SearchAndFilters(
                searching: _searching,
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
    required this.searching,
    required this.controller,
    required this.filter,
    required this.onQuery,
    required this.onFilter,
  });

  final bool searching;
  final TextEditingController controller;
  final DocumentFilter filter;
  final ValueChanged<String> onQuery;
  final ValueChanged<DocumentFilter> onFilter;

  static const _chips = [DocumentFilter.ready, DocumentFilter.sealed];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (searching)
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
              autofocus: true,
              onChanged: onQuery,
              textInputAction: TextInputAction.search,
              style: AppTypography.sm.copyWith(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Search documents',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
          ),
        SizedBox(
          height: AppSpacing.minTouchTarget,
          child: ListView(
            key: const Key('documents_filters'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            children: [
              for (final f in _chips)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s2),
                  child: Center(
                    child: ChoiceChip(
                      key: Key('documents_filter_${f.name}'),
                      label: Text(f.label),
                      selected: f == filter,
                      // Tapping the selected chip again shows everything.
                      onSelected: (on) => onFilter(on ? f : DocumentFilter.all),
                    ),
                  ),
                ),
            ],
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
        onLongPress: () => showDocumentActionsSheet(
          context,
          documentId: document.id,
          title: document.title,
        ),
        child: Container(
          padding: const EdgeInsets.only(
            left: AppSpacing.s3,
            top: AppSpacing.s2,
            bottom: AppSpacing.s2,
            right: AppSpacing.s1,
          ),
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
                    // The status sits with the size and date, so the row has
                    // room for the title and the actions button on a small
                    // phone. A Wrap, not a Row: at large text on a 320px
                    // screen the pill alone nearly fills the line, so the
                    // date drops below it instead of overflowing.
                    Wrap(
                      spacing: AppSpacing.s2,
                      runSpacing: AppSpacing.s1,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusPill(
                          label: abandoned
                              ? 'Incomplete'
                              : documentStatusLabel(document.status),
                          color: statusColor,
                        ),
                        Text(
                          '${formatDocumentSize(document.sizeBytes)} · '
                          '${formatDocumentDate(document.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.mono(
                            AppTypography.xs,
                          ).copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                key: Key('document_menu_${document.id}'),
                tooltip: 'Document actions',
                icon: const Icon(Icons.more_vert),
                color: AppColors.textSecondary,
                onPressed: () => showDocumentActionsSheet(
                  context,
                  documentId: document.id,
                  title: document.title,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
