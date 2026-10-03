import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../documents/data/documents_list_notifier.dart';

/// Document id → title for the signed-in user's documents, from the document
/// list the Documents tab already keeps. Null while that list is loading or
/// failed: "we can't tell yet" is different from "this document isn't here",
/// and the chat must not call a source unavailable just because the list is
/// slow.
final documentTitlesProvider = Provider<Map<String, String>?>((ref) {
  final documents = ref.watch(documentsListProvider);
  // Mid-refresh the list still holds its previous value, but that value is
  // exactly what is being checked: treat the answer as unknown meanwhile, so
  // a source isn't shown as missing just because the refresh that would find
  // it hasn't finished.
  if (documents.isLoading) return null;
  return documents.whenOrNull(
    data: (list) => {for (final d in list) d.id: d.title},
  );
});
