import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/generated_api_client_provider.dart';
import '../../auth/data/current_user_provider.dart';
import '../../documents/data/documents_list_notifier.dart';
import 'chat_message.dart';
import 'chat_sessions_api.dart';
import 'chat_stream_client.dart';
import 'chat_stream_event.dart';
import 'document_titles_provider.dart';

final chatStreamApiProvider = Provider<ChatStreamApi>((ref) {
  return DioChatStreamClient(ref.watch(apiClientProvider).dio);
});

final chatSessionsApiProvider = Provider<ChatSessionsApi>((ref) {
  return ApiChatSessionsApi(ref.watch(generatedApiClientProvider));
});

/// The conversation on screen.
class ChatState {
  const ChatState({this.sessionId, this.messages = const []});

  /// The server-side conversation id, created lazily on the first question.
  final String? sessionId;
  final List<ChatMessage> messages;

  /// A turn is in flight (waiting for retrieval, or the answer is streaming).
  bool get busy => messages.isNotEmpty && messages.last.isStreaming;

  ChatState copyWith({String? sessionId, List<ChatMessage>? messages}) =>
      ChatState(
        sessionId: sessionId ?? this.sessionId,
        messages: messages ?? this.messages,
      );
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);

/// Runs one question at a time: opens a conversation on first use, streams the
/// answer into an assistant message, and handles Stop, retry and "new chat".
class ChatController extends Notifier<ChatState> {
  int _nextId = 0;

  /// Bumped when the signed-in user changes, on "new chat" and on dispose.
  /// Everything that awaits compares against the generation it started in and
  /// drops its result if it no longer matches, so one user's late answer can
  /// never land in the next user's conversation.
  int _generation = 0;

  StreamSubscription<ChatStreamEvent>? _subscription;
  Completer<void>? _turn;

  @override
  ChatState build() {
    ref.watch(currentUserIdProvider);
    _reset();
    ref.onDispose(_reset);
    return const ChatState();
  }

  void _reset() {
    _generation++;
    _subscription?.cancel();
    _subscription = null;
    final turn = _turn;
    _turn = null;
    if (turn != null && !turn.isCompleted) turn.complete();
  }

  /// Starts a fresh conversation (the next question opens a new session).
  void newChat() {
    _reset();
    state = const ChatState();
  }

  /// Asks [question]. Completes when the turn has ended (answered, failed or
  /// stopped). Ignored while another turn is running or if blank.
  Future<void> send(String question) async {
    final query = question.trim();
    if (query.isEmpty || state.busy) return;

    final user = ChatMessage.user(id: _nextId++, text: query);
    final assistant = ChatMessage.assistantPending(id: _nextId++);
    state = state.copyWith(messages: [...state.messages, user, assistant]);
    await _runTurn(query, assistant.id);
  }

  /// Re-asks the question behind the last failed answer, replacing it.
  Future<void> retry() async {
    final messages = state.messages;
    if (state.busy || messages.length < 2) return;
    final last = messages.last;
    final asked = messages[messages.length - 2];
    if (last.role != ChatRole.assistant ||
        last.status != ChatMessageStatus.failed ||
        asked.role != ChatRole.user) {
      return;
    }
    final fresh = ChatMessage.assistantPending(id: _nextId++);
    state = state.copyWith(
      messages: [...messages.sublist(0, messages.length - 1), fresh],
    );
    await _runTurn(asked.text, fresh.id);
  }

  /// Stops the answer in progress, keeping what has arrived.
  void stop() {
    if (!state.busy) return;
    final id = state.messages.last.id;
    final turn = _turn;
    // Invalidate anything still pending for this turn — notably a session
    // that is still being created, which must not go on to start a stream.
    _generation++;
    _subscription?.cancel();
    _subscription = null;
    _update(id, (m) => m.copyWith(status: ChatMessageStatus.stopped));
    if (turn != null && !turn.isCompleted) turn.complete();
  }

  Future<void> _runTurn(String query, int assistantId) async {
    final generation = _generation;
    final turn = _turn = Completer<void>();

    void fail(AppException error) {
      if (generation != _generation) return;
      _update(
        assistantId,
        (m) => m.copyWith(status: ChatMessageStatus.failed, error: error),
      );
      if (!turn.isCompleted) turn.complete();
    }

    String sessionId;
    try {
      sessionId =
          state.sessionId ?? await ref.read(chatSessionsApiProvider).create();
    } on AppException catch (e) {
      fail(e);
      return turn.future;
    } catch (_) {
      fail(const UnknownApiException());
      return turn.future;
    }
    if (generation != _generation) return;
    if (state.sessionId == null) {
      state = state.copyWith(sessionId: sessionId);
    }

    _subscription = ref
        .read(chatStreamApiProvider)
        .stream(sessionId: sessionId, query: query)
        .listen(
          (event) {
            if (generation != _generation) return;
            _apply(assistantId, event, turn);
          },
          onError: (Object error) =>
              fail(error is AppException ? error : const UnknownApiException()),
          onDone: () {
            if (!turn.isCompleted) turn.complete();
          },
        );
    return turn.future;
  }

  void _apply(int id, ChatStreamEvent event, Completer<void> turn) {
    switch (event) {
      case ChatHeartbeat():
        break;
      case ChatRetrieval(:final chunkIds):
        _update(
          id,
          (m) => m.copyWith(
            retrievalDone: true,
            retrievedChunkIds: chunkIds.toSet(),
          ),
        );
      case ChatToken(:final text):
        _update(id, (m) => m.copyWith(text: m.text + text));
      case ChatCitation(:final chunkId, :final documentId):
        _update(
          id,
          (m) => m.copyWith(
            citedDocuments: {...m.citedDocuments, chunkId: documentId},
          ),
        );
      case ChatDone():
        _update(id, (m) => m.copyWith(status: ChatMessageStatus.complete));
        _refreshDocumentsIfSourceUnknown(id);
        if (!turn.isCompleted) turn.complete();
      case ChatError():
        _update(
          id,
          (m) => m.copyWith(
            status: ChatMessageStatus.failed,
            error: UnknownApiException(event.userMessage),
          ),
        );
        if (!turn.isCompleted) turn.complete();
    }
  }

  /// The answer cites a document the loaded document list has never heard
  /// of. Usually that list is simply stale (a document uploaded from another
  /// device since it loaded); declaring the source "no longer available" on
  /// that evidence alone would mark a perfectly good citation dead. So look
  /// again first — only a document still missing from a fresh list is gone.
  void _refreshDocumentsIfSourceUnknown(int id) {
    final titles = ref.read(documentTitlesProvider);
    // List loading or unavailable: nothing to compare against.
    if (titles == null) return;
    final message = state.messages.where((m) => m.id == id).firstOrNull;
    if (message == null) return;
    final unknown = message.citedDocuments.values.any(
      (documentId) => !titles.containsKey(documentId),
    );
    if (unknown && ref.exists(documentsListProvider)) {
      ref.read(documentsListProvider.notifier).refresh();
    }
  }

  void _update(int id, ChatMessage Function(ChatMessage) change) {
    state = state.copyWith(
      messages: [
        for (final m in state.messages)
          if (m.id == id) change(m) else m,
      ],
    );
  }
}
