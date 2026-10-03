import '../../../core/network/app_exception.dart';

enum ChatRole { user, assistant }

/// Where an assistant answer is in its life.
enum ChatMessageStatus {
  /// Being generated (including the wait for retrieval).
  streaming,

  /// Finished normally (`done`).
  complete,

  /// Ended by a failure. Whatever text arrived is kept.
  failed,

  /// The user pressed Stop. Whatever text arrived is kept.
  stopped,
}

/// One bubble in the conversation, as the UI draws it.
final class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    this.text = '',
    this.status = ChatMessageStatus.complete,
    this.retrievalDone = false,
    this.retrievedChunkIds = const {},
    this.citedDocuments = const {},
    this.error,
  });

  const ChatMessage.user({required int id, required String text})
    : this(id: id, role: ChatRole.user, text: text);

  const ChatMessage.assistantPending({required int id})
    : this(
        id: id,
        role: ChatRole.assistant,
        status: ChatMessageStatus.streaming,
      );

  final int id;
  final ChatRole role;

  /// The answer text so far, **raw** — still containing `[[chunk:…]]`
  /// markers. Never draw this directly; go through `parseAnswerSegments` and
  /// `resolveAnswer`.
  final String text;
  final ChatMessageStatus status;

  /// Retrieval has reported (its `retrieval` event arrived).
  final bool retrievalDone;

  /// The chunk ids retrieval returned for this turn.
  final Set<String> retrievedChunkIds;

  /// The server's `citation` events: chunk id → document id.
  final Map<String, String> citedDocuments;

  /// Why a failed turn failed, in words fit for the user.
  final AppException? error;

  bool get isStreaming => status == ChatMessageStatus.streaming;

  /// Retrieval ran and found nothing to ground an answer in. Distinct from a
  /// turn still waiting on retrieval, and from a normal cited answer.
  bool get retrievalFoundNothing => retrievalDone && retrievedChunkIds.isEmpty;

  ChatMessage copyWith({
    String? text,
    ChatMessageStatus? status,
    bool? retrievalDone,
    Set<String>? retrievedChunkIds,
    Map<String, String>? citedDocuments,
    AppException? error,
  }) => ChatMessage(
    id: id,
    role: role,
    text: text ?? this.text,
    status: status ?? this.status,
    retrievalDone: retrievalDone ?? this.retrievalDone,
    retrievedChunkIds: retrievedChunkIds ?? this.retrievedChunkIds,
    citedDocuments: citedDocuments ?? this.citedDocuments,
    error: error ?? this.error,
  );
}
