import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../documents/data/documents_list_notifier.dart';

/// Document id → title for the signed-in user's documents, from the document
/// list the Documents tab already keeps. Null while that list is loading or
/// failed: "we can't tell yet" is different from "this document isn't here",
/// and the chat must not call a source unavailable just because the list is
/// slow.
final documentTitlesProvider = Provider<Map<String, String>?>((ref) {
  final documents = ref.watch(documentsListProvider);
  return documents.whenOrNull(
    data: (list) => {for (final d in list) d.id: d.title},
  );
});
