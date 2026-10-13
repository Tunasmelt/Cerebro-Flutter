import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/network/app_exception.dart';
import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../data/delete_document_controller.dart';
import 'rename_document_dialog.dart';

/// What can be done to a document from the list or the file view: rename it,
/// open its details, delete it.
Future<void> showDocumentActionsSheet(
  BuildContext context, {
  required String documentId,
  required String title,
  VoidCallback? onDeleted,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // Over the app shell's bottom nav, not inside it.
    useRootNavigator: true,
    backgroundColor: AppColors.bgElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4,
          AppSpacing.s4,
          AppSpacing.s4,
          AppSpacing.s2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.md.copyWith(
                color: AppColors.textPrimary,
                fontWeight: AppTypography.weightSemibold,
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            _ActionTile(
              tileKey: const Key('document_action_rename'),
              icon: Icons.edit_outlined,
              label: 'Rename',
              onTap: () async {
                Navigator.of(sheetContext).pop();
                if (!context.mounted) return;
                await showRenameDocumentDialog(
                  context,
                  documentId: documentId,
                  currentTitle: title,
                );
              },
            ),
            _ActionTile(
              tileKey: const Key('document_action_details'),
              icon: Icons.info_outline,
              label: 'Details',
              onTap: () {
                Navigator.of(sheetContext).pop();
                if (context.mounted) {
                  context.push(AppRoutes.documentDetail(documentId));
                }
              },
            ),
            _ActionTile(
              tileKey: const Key('document_action_delete'),
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              destructive: true,
              onTap: () async {
                Navigator.of(sheetContext).pop();
                if (!context.mounted) return;
                final deleted = await confirmAndDeleteDocument(
                  context,
                  ProviderScope.containerOf(context, listen: false),
                  documentId: documentId,
                  title: title,
                );
                if (deleted) onDeleted?.call();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.tileKey,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final Key tileKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.danger : AppColors.textPrimary;
    return ListTile(
      key: tileKey,
      contentPadding: EdgeInsets.zero,
      minTileHeight: AppSpacing.minTouchTarget,
      leading: Icon(
        icon,
        color: destructive ? AppColors.danger : AppColors.textSecondary,
      ),
      title: Text(label, style: AppTypography.base.copyWith(color: color)),
      onTap: onTap,
    );
  }
}

/// Asks, then deletes. Returns true once the document is gone. A refusal is
/// shown in a snackbar (there is no screen of its own to put it on). Works for
/// any status, sealed included: deleting needs ownership, not the passphrase.
Future<bool> confirmAndDeleteDocument(
  BuildContext context,
  ProviderContainer container, {
  required String documentId,
  required String title,
}) async {
  final confirmed = await showAppConfirmDialog(
    context,
    title: 'Delete this document?',
    message:
        '"$title" and everything made from it will be removed. This can\'t be '
        'undone.',
    confirmLabel: 'Delete',
    destructive: true,
    confirmKey: const Key('document_delete_confirm'),
    cancelKey: const Key('document_delete_cancel'),
  );
  if (!confirmed) return false;
  // The controller is auto-disposed: hold it open for the whole request, or it
  // is disposed mid-flight and drops its own answer.
  final hold = container.listen(deleteDocumentProvider(documentId), (_, _) {});
  final bool deleted;
  try {
    deleted = await container
        .read(deleteDocumentProvider(documentId).notifier)
        .delete();
  } catch (_) {
    hold.close();
    rethrow;
  }
  if (deleted) {
    hold.close();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            key: Key('document_deleted_message'),
            content: Text('Document deleted.'),
          ),
        );
    }
    return true;
  }
  final error = container.read(deleteDocumentProvider(documentId)).error;
  hold.close();
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('document_delete_error'),
          content: Text(
            error is AppException ? error.message : "Couldn't delete.",
          ),
        ),
      );
  }
  return false;
}
