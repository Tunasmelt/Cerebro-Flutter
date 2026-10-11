import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Remove temporary originals left by a process killed before opening its PDF.
Future<void> clearDocumentViewCache({Directory? directory}) async {
  final cache = directory ?? await getApplicationCacheDirectory();
  if (!await cache.exists()) return;
  await for (final entry in cache.list(followLinks: false)) {
    final name = entry.uri.pathSegments.where((part) => part.isNotEmpty).last;
    if (entry is Directory &&
        (name.startsWith('document-view-') || name == 'pdf_renderer_cache')) {
      await entry.delete(recursive: true);
    }
  }
}
