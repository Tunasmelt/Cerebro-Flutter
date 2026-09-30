import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/generated_api_client_provider.dart';
import 'documents_repository.dart';

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  return ApiDocumentsRepository(ref.watch(generatedApiClientProvider));
});
