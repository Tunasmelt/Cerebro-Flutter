import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// The app's one confirmation dialog. Resolves to `true` only when the user
/// confirms; cancelling, tapping outside or the system back gesture all give
/// `false`, so a caller can write `if (!await showAppConfirmDialog(...)) return;`
/// without a null case.
///
/// A [destructive] confirm (delete, wipe) is red; nothing else is. The styling
/// comes from the theme's `DialogTheme`, so every dialog in the app looks the
/// same.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  Key? confirmKey,
  Key? cancelKey,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          key: cancelKey ?? const Key('app_confirm_cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: Text(cancelLabel),
        ),
        TextButton(
          key: confirmKey ?? const Key('app_confirm_confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: destructive
              ? TextButton.styleFrom(foregroundColor: AppColors.danger)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}
