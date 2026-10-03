import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/generated_api_client_provider.dart';
import '../../auth/data/current_user_provider.dart';
import 'delete_document_api.dart';
import 'documents_list_notifier.dart';

final deleteDocumentApiProvider = Provider<DeleteDocumentApi>((ref) {
  return ApiDeleteDocumentApi(ref.watch(generatedApiClientProvider));
});

/// Deleting one document: idle (`AsyncData`), in flight (`AsyncLoading`) or
/// refused (`AsyncError` holding an [AppException]).
final deleteDocumentProvider = NotifierProvider.autoDispose
    .family<DeleteDocumentController, AsyncValue<void>, String>(
      DeleteDocumentController.new,
    );

class DeleteDocumentController
    extends AutoDisposeFamilyNotifier<AsyncValue<void>, String> {
  /// Bumped on rebuild (user change) and dispose, so an answer that lands
  /// after the screen closed or the user changed is dropped.
  int _generation = 0;

  @override
  AsyncValue<void> build(String documentId) {
    ref.watch(currentUserIdProvider);
    _generation++;
    ref.onDispose(() => _generation++);
    return const AsyncData(null);
  }

  /// Returns true once the document is gone (deleted now, or already gone),
  /// so the caller can leave a screen that no longer has anything to show.
  Future<bool> delete() async {
    // One request at a time: a second tap while one is in flight is a no-op.
    if (state.isLoading) return false;
    final documentId = arg;
    final generation = _generation;
    state = const AsyncLoading();

    try {
      await ref.read(deleteDocumentApiProvider).delete(documentId);
    } on AppException catch (error) {
      if (generation != _generation) return false;
      if (!isAlreadyDeleted(error)) {
        state = AsyncError(error, StackTrace.current);
        return false;
      }
    } catch (_) {
      if (generation != _generation) return false;
      state = AsyncError(const UnknownApiException(), StackTrace.current);
      return false;
    }

    if (generation != _generation) return false;
    state = const AsyncData(null);
    if (ref.exists(documentsListProvider)) {
      ref.read(documentsListProvider.notifier).removeDocument(documentId);
    }
    return true;
  }
}
