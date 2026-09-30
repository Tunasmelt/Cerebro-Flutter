import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'document.dart';
import 'documents_repository_provider.dart';

final documentDetailProvider = FutureProvider.family<DocumentDetail, String>((
  ref,
  documentId,
) {
  return ref.read(documentsRepositoryProvider).getDocument(documentId);
});
