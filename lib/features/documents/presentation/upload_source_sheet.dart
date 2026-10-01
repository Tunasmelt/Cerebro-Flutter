import 'package:flutter/material.dart';

import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import '../data/upload/upload_picker.dart';

/// Where the new document comes from. The one upload UX mobile does
/// better than desktop (architecture-and-spec.md §3): camera and photo
/// library sit next to the plain file picker, all feeding the same
/// three-call flow.
Future<UploadSource?> showUploadSourceSheet(BuildContext context) {
  return showModalBottomSheet<UploadSource>(
    context: context,
    // Over the app shell's bottom nav, not inside it.
    useRootNavigator: true,
    backgroundColor: AppColors.bgElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (context) => const _UploadSourceSheet(),
  );
}

class _UploadSourceSheet extends StatelessWidget {
  const _UploadSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
              'Add a document',
              style: AppTypography.md.copyWith(
                color: AppColors.textPrimary,
                fontWeight: AppTypography.weightSemibold,
              ),
            ),
            const SizedBox(height: AppSpacing.s1),
            Text(
              'PDF, images, plain text, markdown — up to 50MB',
              style: AppTypography.xs.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s2),
            const _SourceTile(
              tileKey: Key('upload_source_file'),
              icon: Icons.folder_open_outlined,
              label: 'Choose a file',
              source: UploadSource.file,
            ),
            const _SourceTile(
              tileKey: Key('upload_source_photos'),
              icon: Icons.photo_library_outlined,
              label: 'Photo library',
              source: UploadSource.photoLibrary,
            ),
            const _SourceTile(
              tileKey: Key('upload_source_camera'),
              icon: Icons.photo_camera_outlined,
              label: 'Take a photo',
              source: UploadSource.camera,
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.tileKey,
    required this.icon,
    required this.label,
    required this.source,
  });

  final Key tileKey;
  final IconData icon;
  final String label;
  final UploadSource source;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: tileKey,
      contentPadding: EdgeInsets.zero,
      minTileHeight: AppSpacing.minTouchTarget,
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(
        label,
        style: AppTypography.base.copyWith(color: AppColors.textPrimary),
      ),
      onTap: () => Navigator.of(context).pop(source),
    );
  }
}
