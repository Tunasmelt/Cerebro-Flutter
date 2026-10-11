import 'dart:io';

import 'package:cerebro_mobile/features/documents/data/document_view_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'startup removes interrupted viewer copies and preserves upload recovery',
    () async {
      final cache = await Directory.systemTemp.createTemp('viewer-cache-test-');
      addTearDown(() => cache.delete(recursive: true));
      final stale = await Directory(
        '${cache.path}/document-view-interrupted',
      ).create();
      await File(
        '${stale.path}/original.pdf',
      ).writeAsString('private original');
      final pageCache = await Directory('${cache.path}/pdf_renderer_cache').create();
      await File('${pageCache.path}/page.png').writeAsString('interrupted render');
      final uploads = await Directory('${cache.path}/pending_uploads').create();
      await File('${uploads.path}/bytes').writeAsString('recoverable upload');
      await clearDocumentViewCache(directory: cache);
      expect(await stale.exists(), isFalse);
      expect(await pageCache.exists(), isFalse);
      expect(
        await File('${uploads.path}/bytes').readAsString(),
        'recoverable upload',
      );
    },
  );
}
