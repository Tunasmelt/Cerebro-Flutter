import 'dart:convert';

import '../../../core/sse/sse_event.dart';

/// One event of `POST /chat/sessions/{id}/stream`, typed. The wire contract
/// (api-documentation.md, "Chat / retrieval"; `chat/stream.py`):
///
///   zero or more `heartbeat`   — only ever before `retrieval`
///   `retrieval`  { chunk_ids, document_ids } — always before the first token
///   `token`      { text }                    — repeated
///   `citation`   { chunk_id, document_id }   — repeated, after the tokens
///   `done`                                   — end of a successful turn
///   or `error`   { code, message }           — in place of the rest; no
///                                              `done` follows
sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

/// "Still working" — retrieval is running and nothing has come back yet.
final class ChatHeartbeat extends ChatStreamEvent {
  const ChatHeartbeat();
}

/// What retrieval found. Arrives before any token.
final class ChatRetrieval extends ChatStreamEvent {
  const ChatRetrieval({required this.chunkIds, required this.documentIds});

  final List<String> chunkIds;
  final List<String> documentIds;

  /// Retrieval found nothing relevant to ground an answer in.
  bool get isEmpty => chunkIds.isEmpty;
}

/// A piece of the answer, to be appended to what is already shown.
final class ChatToken extends ChatStreamEvent {
  const ChatToken(this.text);

  final String text;
}

/// The model cited a retrieved chunk. The server has already dropped any
/// marker naming a chunk outside the retrieved set.
final class ChatCitation extends ChatStreamEvent {
  const ChatCitation({required this.chunkId, required this.documentId});

  final String chunkId;
  final String documentId;
}

/// The turn finished successfully.
final class ChatDone extends ChatStreamEvent {
  const ChatDone();
}

/// The turn failed partway. The stream ends after this.
///
/// [code] and [rawMessage] are the server's, for logs and diagnostics only:
/// `rawMessage` is the exception text from the backend (`str(exc)` or just
/// the exception's type name, e.g. `ReadTimeout`), which is not written for
/// users and can be empty. The UI shows [userMessage].
final class ChatError extends ChatStreamEvent {
  const ChatError({required this.code, required this.rawMessage});

  final String code;
  final String rawMessage;

  String get userMessage =>
      "Something went wrong while answering. Try asking again.";
}

/// Turns a parsed [SseEvent] into a [ChatStreamEvent].
///
/// Returns `null` for an event name this client doesn't know — a newer
/// server may add events, and ignoring them is how a client stays
/// compatible. Throws [FormatException] when a *known* event's payload is
/// not what the contract says (not JSON, wrong shape): that is a protocol
/// violation, not something to guess around.
ChatStreamEvent? chatEventFromSse(SseEvent event) {
  switch (event.event) {
    case 'heartbeat':
      return const ChatHeartbeat();
    case 'done':
      return const ChatDone();
    case 'retrieval':
      final data = _object(event);
      return ChatRetrieval(
        chunkIds: _stringList(data, 'chunk_ids', event),
        documentIds: _stringList(data, 'document_ids', event),
      );
    case 'token':
      return ChatToken(_string(_object(event), 'text', event));
    case 'citation':
      final data = _object(event);
      return ChatCitation(
        chunkId: _string(data, 'chunk_id', event),
        documentId: _string(data, 'document_id', event),
      );
    case 'error':
      final data = _object(event);
      return ChatError(
        code: data['code'] is String ? data['code'] as String : 'unknown',
        rawMessage: data['message'] is String ? data['message'] as String : '',
      );
    default:
      return null;
  }
}

Map<String, dynamic> _object(SseEvent event) {
  final Object? decoded;
  try {
    decoded = jsonDecode(event.data);
  } on FormatException {
    throw FormatException('`${event.event}` event is not JSON', event.data);
  }
  if (decoded is! Map<String, dynamic>) {
    throw FormatException(
      '`${event.event}` event is not an object',
      event.data,
    );
  }
  return decoded;
}

String _string(Map<String, dynamic> data, String key, SseEvent event) {
  final value = data[key];
  if (value is! String) {
    throw FormatException(
      '`${event.event}` event has no string `$key`',
      event.data,
    );
  }
  return value;
}

List<String> _stringList(
  Map<String, dynamic> data,
  String key,
  SseEvent event,
) {
  final value = data[key];
  if (value == null) return const [];
  if (value is! List || value.any((e) => e is! String)) {
    throw FormatException(
      '`${event.event}` event `$key` is not a list of strings',
      event.data,
    );
  }
  return List<String>.from(value);
}
