import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/generated_api_client_provider.dart';
import '../../auth/data/current_user_provider.dart';
import 'document_detail_provider.dart';
import 'documents_list_notifier.dart';
import 'retry_ingest_api.dart';

final retryIngestApiProvider = Provider<RetryIngestApi>((ref) {
  return ApiRetryIngestApi(ref.watch(generatedApiClientProvider));
});

/// Retrying one failed document: idle (`AsyncData`), in flight
/// (`AsyncLoading`) or refused (`AsyncError` holding an [AppException]).
final retryIngestProvider = NotifierProvider.autoDispose
    .family<RetryIngestController, AsyncValue<void>, String>(
      RetryIngestController.new,
    );

class RetryIngestController
    extends AutoDisposeFamilyNotifier<AsyncValue<void>, String> {
  /// Bumped on rebuild (user change) and dispose, so a response that lands
  /// after the screen closed or the user changed is dropped, not applied.
  int _generation = 0;

  @override
  AsyncValue<void> build(String documentId) {
    ref.watch(currentUserIdProvider);
    _generation++;
    ref.onDispose(() => _generation++);
    return const AsyncData(null);
  }

  Future<void> retry() async {
    // One request at a time: a second tap while one is in flight is a no-op.
    if (state.isLoading) return;
    final documentId = arg;
    final generation = _generation;
    state = const AsyncLoading();

    try {
      await ref.read(retryIngestApiProvider).retry(documentId);
    } on AppException catch (error) {
      if (generation != _generation) return;
      state = AsyncError(friendlyRetryError(error), StackTrace.current);
      // A refusal usually means our picture is stale (retried elsewhere,
      // already finished) — re-read the document so the screen shows the
      // truth rather than a Retry button that no longer applies.
      ref.invalidate(documentDetailProvider(documentId));
      return;
    } catch (_) {
      if (generation != _generation) return;
      state = AsyncError(const UnknownApiException(), StackTrace.current);
      return;
    }

    if (generation != _generation) return;
    state = const AsyncData(null);
    // The job was reset server-side: start watching it from the top, and
    // tell the list it is no longer simply "failed".
    ref.invalidate(documentDetailProvider(documentId));
    if (ref.exists(documentsListProvider)) {
      ref.read(documentsListProvider.notifier).markRetrying(documentId);
    }
  }
}
