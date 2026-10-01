import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/current_user_provider.dart';
import 'document.dart';
import 'documents_repository_provider.dart';

final documentDetailProvider = FutureProvider.family<DocumentDetail, String>((
  ref,
  documentId,
) {
  // Watched so a cached detail never outlives the user it belongs to.
  ref.watch(currentUserIdProvider);
  return ref.read(documentsRepositoryProvider).getDocument(documentId);
});
