import 'package:flutter/material.dart';

import '../../../shared/tokens/app_colors.dart';
import '../data/document.dart';

/// Visual mapping for a document's mime type and status. Colors follow
/// `Mockups 2.0/src/components/Documents.tsx` (the web reference) for
/// PDF/JPG/PNG, but deliberately **diverge from it for Markdown and for
/// "processing"**: that mockup uses amber for both, and
/// `AppColors.accentLocked` (amber) is reserved exclusively for sealed/
/// encryption UI project-wide (enforced by
/// `test/shared/app_colors_test.dart`) — amber here would blur that
/// meaning the first time a real Markdown file or an in-progress upload
/// appeared next to an actually-sealed document.
String documentTypeLabel(String mime) {
  switch (mime) {
    case 'application/pdf':
      return 'PDF';
    case 'image/jpeg':
      return 'JPG';
    case 'image/png':
      return 'PNG';
    case 'image/webp':
      return 'WEBP';
    case 'text/markdown':
      return 'MD';
    case 'text/plain':
      return 'TXT';
    default:
      final parts = mime.split('/');
      final subtype = parts.isEmpty ? '' : parts.last;
      return subtype.isEmpty ? 'FILE' : subtype.toUpperCase();
  }
}

Color documentTypeColor(String mime) {
  switch (documentTypeLabel(mime)) {
    case 'PDF':
      return AppColors.danger;
    case 'JPG':
    case 'WEBP':
      return AppColors.accentSecondary;
    case 'PNG':
      return AppColors.accentSuccess;
    case 'MD':
      // Not amber — see this file's top comment.
      return AppColors.accentPrimary;
    default:
      return AppColors.textSecondary;
  }
}

String documentStatusLabel(DocumentStatus status) {
  switch (status) {
    case DocumentStatus.processing:
      return 'Processing';
    case DocumentStatus.ready:
      return 'Ready';
    case DocumentStatus.failed:
      return 'Failed';
    case DocumentStatus.sealed:
      return 'Sealed';
    case DocumentStatus.unknown:
      return 'Unknown';
  }
}

Color documentStatusColor(DocumentStatus status) {
  switch (status) {
    case DocumentStatus.processing:
      return AppColors.accentSecondary;
    case DocumentStatus.ready:
      return AppColors.accentSuccess;
    case DocumentStatus.failed:
      return AppColors.danger;
    case DocumentStatus.sealed:
      return AppColors.accentLocked;
    case DocumentStatus.unknown:
      return AppColors.textSecondary;
  }
}

String formatDocumentSize(int bytes) {
  if (bytes < 1024) return '${bytes}b';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}kb';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}mb';
}

String formatDocumentDate(DateTime date) {
  final local = date.toLocal();
  return '${local.month}/${local.day}/${local.year}';
}
