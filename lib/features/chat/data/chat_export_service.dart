import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import 'chat_controller.dart';
import 'chat_history_api.dart';
import 'chat_message.dart';
import 'conversation_exporter.dart';
import 'document_titles_provider.dart';
import 'export_markdown.dart';

final conversationExporterProvider = Provider<ConversationExporter>(
  (ref) => const ShareConversationExporter(),
);

final chatExportServiceProvider = Provider<ChatExportService>(
  (ref) => ChatExportService(ref),
);

/// Exports a conversation to Markdown and hands it to the user.
///
/// Every failure is reported as an [AppException] with words fit for the
/// user; nothing else escapes.
class ChatExportService {
  ChatExportService(this._ref);

  final Ref _ref;

  /// The conversation open in the Chat tab (live or restored).
  Future<void> exportOpenConversation() async {
    final state = _ref.read(chatControllerProvider);
    final sessionId = state.sessionId;
    if (sessionId == null || state.messages.isEmpty) {
      throw const UnknownApiException('There is nothing to export yet.');
    }
    final titles = _ref.read(documentTitlesProvider);
    await _write(
      sessionId: sessionId,
      startedAt:
          state.startedAt ?? state.messages.first.createdAt ?? DateTime.now(),
      messages: state.messages,
      titles: titles,
    );
  }

  /// A past conversation, fetched fresh so the export reflects the server's
  /// record rather than whatever was last on screen.
  Future<void> exportSession(ChatSessionSummary session) async {
    final ChatHistory history;
    try {
      history = await _ref.read(chatHistoryApiProvider).messages(session.id);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const UnknownApiException();
    }
    if (history.messages.isEmpty) {
      throw const UnknownApiException('There is nothing to export yet.');
    }
    await _write(
      sessionId: session.id,
      startedAt: session.createdAt,
      messages: history.messages,
      titles: _ref.read(documentTitlesProvider),
    );
  }

  Future<void> _write({
    required String sessionId,
    required DateTime startedAt,
    required List<ChatMessage> messages,
    required Map<String, String>? titles,
  }) async {
    final markdown = exportConversationMarkdown(
      startedAt: startedAt,
      messages: messages,
      documentTitle: (id) => titles?[id] ?? 'Source document',
    );
    try {
      await _ref
          .read(conversationExporterProvider)
          .export(fileName: exportFileName(sessionId), markdown: markdown);
    } catch (_) {
      throw const UnknownApiException("Couldn't export this conversation.");
    }
  }
}
