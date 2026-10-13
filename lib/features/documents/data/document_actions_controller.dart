import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/generated_api_client_provider.dart';
import '../../auth/data/current_user_provider.dart';
import 'document_actions_api.dart';
import 'document_detail_provider.dart';
import 'documents_list_notifier.dart';

final documentActionsApiProvider = Provider<DocumentActionsApi>((ref) {
  return ApiDocumentActionsApi(ref.watch(generatedApiClientProvider));
});

final documentActionsProvider = Provider<DocumentActions>(DocumentActions.new);

/// Rename and note capture, plus the bookkeeping that keeps the lists in step
/// afterwards. Both throw an `AppException` the caller shows; neither touches
/// state belonging to a different user if the account changed while the
/// request was in flight.
class DocumentActions {
  DocumentActions(this._ref);

  final Ref _ref;

  Future<void> rename(String documentId, String title) async {
    final owner = _ref.read(currentUserIdProvider);
    final trimmed = title.trim();
    await _ref.read(documentActionsApiProvider).rename(documentId, trimmed);
    if (_ref.read(currentUserIdProvider) != owner) return;
    if (_ref.exists(documentsListProvider)) {
      _ref
          .read(documentsListProvider.notifier)
          .renameDocument(documentId, trimmed);
    }
    _ref.invalidate(documentDetailProvider(documentId));
  }

  /// Saves [text] as a note (a document of its own) and returns its id. The
  /// list is refreshed so the note appears, processing, and the list's own
  /// polling carries it to ready.
  Future<String> createNote({required String text, String? title}) async {
    final owner = _ref.read(currentUserIdProvider);
    // One place normalises what goes out: the text trimmed, and a blank title
    // sent as none so the server names the note from its first words.
    final trimmedTitle = title?.trim();
    final id = await _ref
        .read(documentActionsApiProvider)
        .createNote(
          text: text.trim(),
          title: trimmedTitle == null || trimmedTitle.isEmpty
              ? null
              : trimmedTitle,
        );
    if (_ref.read(currentUserIdProvider) == owner &&
        _ref.exists(documentsListProvider)) {
      // Not awaited: the note is saved; the list catches up on its own.
      _ref.read(documentsListProvider.notifier).refresh();
    }
    return id;
  }
}
