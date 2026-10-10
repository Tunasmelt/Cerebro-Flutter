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
    this.citationTitles = const {},
    this.createdAt,
    this.error,
  });

  const ChatMessage.user({
    required int id,
    required String text,
    DateTime? createdAt,
  }) : this(id: id, role: ChatRole.user, text: text, createdAt: createdAt);

  /// A message restored from `GET /chat/sessions/{id}/messages`, or null for
  /// a row this client can't use (a role other than user/assistant, or not an
  /// object at all). History is only ever *complete* turns: the server saves
  /// an answer when it finishes, so there is nothing streaming or failed to
  /// restore.
  static ChatMessage? fromHistory(Object? json, {required int id}) {
    if (json is! Map) return null;
    final role = json['role'];
    if (role != 'user' && role != 'assistant') return null;
    final text = json['content'] is String ? json['content'] as String : '';
    final createdAt = json['created_at'] is String
        ? DateTime.tryParse(json['created_at'] as String)
        : null;

    if (role == 'user') {
      return ChatMessage.user(id: id, text: text, createdAt: createdAt);
    }

    final chunkIds = json['retrieved_chunk_ids'];
    final citedDocuments = <String, String>{};
    final citationTitles = <String, String>{};
    final citations = json['citations'];
    if (citations is List) {
      for (final c in citations) {
        if (c is! Map) continue;
        final chunk = c['chunk_id'];
        final document = c['document_id'];
        if (chunk is! String || document is! String) continue;
        citedDocuments[chunk] = document;
        final title = c['document_title'];
        if (title is String && title.trim().isNotEmpty) {
          citationTitles[document] = title;
        }
      }
    }
    return ChatMessage(
      id: id,
      role: ChatRole.assistant,
      text: text,
      createdAt: createdAt,
      // A stored answer always had its retrieval; whether it found anything
      // is what `retrieved_chunk_ids` says.
      retrievalDone: true,
      retrievedChunkIds: {
        if (chunkIds is List)
          for (final c in chunkIds)
            if (c is String) c,
      },
      citedDocuments: citedDocuments,
      citationTitles: citationTitles,
    );
  }

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

  /// Document id → title for the documents this answer cites, when the
  /// server supplied them (a restored conversation). The server resolved
  /// these against documents that exist *now*, so a title here also vouches
  /// that the document is still there — independent of the app's own,
  /// possibly stale, document list.
  final Map<String, String> citationTitles;

  /// When the message was sent (restored messages) or created (live ones).
  final DateTime? createdAt;

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
    citationTitles: citationTitles,
    createdAt: createdAt,
    error: error ?? this.error,
  );
}
