import 'package:chopper/chopper.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/generated/cerebro_api.swagger.dart';
import '../../documents/data/documents_error_mapper.dart';
import 'chat_message.dart';

/// One row of `GET /chat/sessions`: a past conversation, most recent first.
final class ChatSessionSummary {
  const ChatSessionSummary({
    required this.id,
    required this.createdAt,
    this.preview,
  });

  final String id;
  final DateTime createdAt;

  /// The conversation's first question, truncated by the server. Null for a
  /// conversation with no question in it.
  final String? preview;

  static ChatSessionSummary? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final created = json['created_at'] is String
        ? DateTime.tryParse(json['created_at'] as String)
        : null;
    if (id is! String || created == null) return null;
    final preview = json['preview'];
    return ChatSessionSummary(
      id: id,
      createdAt: created,
      preview: preview is String && preview.trim().isNotEmpty
          ? preview.trim()
          : null,
    );
  }
}

/// A past conversation, restored.
final class ChatHistory {
  const ChatHistory({required this.messages});
  final List<ChatMessage> messages;
}

/// The conversation-management endpoints: list, reopen, delete.
abstract interface class ChatHistoryApi {
  Future<List<ChatSessionSummary>> list();

  /// A conversation's messages, oldest first, with each answer's citations
  /// already resolved by the server. 404 (gone) is a `RequestRejectedException`
  /// with code `not_found`.
  Future<ChatHistory> messages(String sessionId);

  /// Deletes a conversation and its messages. 404 is a
  /// `RequestRejectedException` with code `not_found`.
  Future<void> delete(String sessionId);
}

class ApiChatHistoryApi implements ChatHistoryApi {
  ApiChatHistoryApi(this._api);

  final CerebroApi _api;

  Future<Response> _run(Future<Response> request) async {
    final Response response;
    try {
      response = await request;
    } catch (error) {
      throw DocumentsErrorMapper.ofException(error);
    }
    if (!response.isSuccessful) throw DocumentsErrorMapper.ofResponse(response);
    return response;
  }

  @override
  Future<List<ChatSessionSummary>> list() async {
    final response = await _run(_api.apiV1ChatSessionsGet());
    final body = response.body;
    final sessions = body is Map ? body['sessions'] : null;
    if (sessions is! List) {
      throw const UnknownApiException('Unexpected response from the server.');
    }
    return [for (final row in sessions) ?ChatSessionSummary.fromJson(row)];
  }

  @override
  Future<ChatHistory> messages(String sessionId) async {
    final response = await _run(
      _api.apiV1ChatSessionsSessionIdMessagesGet(sessionId: sessionId),
    );
    final body = response.body;
    final rows = body is Map ? body['messages'] : null;
    if (rows is! List) {
      throw const UnknownApiException('Unexpected response from the server.');
    }
    final messages = <ChatMessage>[];
    for (final row in rows) {
      final message = ChatMessage.fromHistory(row, id: messages.length);
      if (message != null) messages.add(message);
    }
    return ChatHistory(messages: messages);
  }

  @override
  Future<void> delete(String sessionId) async {
    await _run(_api.apiV1ChatSessionsSessionIdDelete(sessionId: sessionId));
  }
}
