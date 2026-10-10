// Reopening, listing, deleting and exporting conversations — against fakes.
import 'dart:async';

import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/chat/data/chat_controller.dart';
import 'package:cerebro_mobile/features/chat/data/chat_export_service.dart';
import 'package:cerebro_mobile/features/chat/data/chat_history_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_message.dart';
import 'package:cerebro_mobile/features/chat/data/chat_sessions_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_sessions_list.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_client.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_event.dart';
import 'package:cerebro_mobile/features/chat/data/conversation_exporter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeHistory implements ChatHistoryApi {
  List<ChatSessionSummary> sessions = [];
  final Map<String, List<ChatMessage>> messagesBySession = {};
  Object? listError;
  Object? messagesError;
  Object? deleteError;
  Completer<void>? messagesGate;
  final List<String> deleted = [];
  int listCalls = 0;

  @override
  Future<List<ChatSessionSummary>> list() async {
    listCalls++;
    final e = listError;
    if (e != null) throw e;
    return List.of(sessions);
  }

  @override
  Future<ChatHistory> messages(String sessionId) async {
    await messagesGate?.future;
    final e = messagesError;
    if (e != null) throw e;
    return ChatHistory(messages: messagesBySession[sessionId] ?? const []);
  }

  @override
  Future<void> delete(String sessionId) async {
    deleted.add(sessionId);
    final e = deleteError;
    if (e != null) throw e;
    sessions.removeWhere((s) => s.id == sessionId);
  }
}

class _Turn {
  _Turn(this.sessionId, this.query);
  final String sessionId;
  final String query;
  bool cancelled = false;
  late final StreamController<ChatStreamEvent> controller =
      StreamController<ChatStreamEvent>(onCancel: () => cancelled = true);
}

class _FakeStream implements ChatStreamApi {
  final List<_Turn> turns = [];
  @override
  Stream<ChatStreamEvent> stream({
    required String sessionId,
    required String query,
  }) {
    final turn = _Turn(sessionId, query);
    turns.add(turn);
    return turn.controller.stream;
  }
}

class _FakeSessions implements ChatSessionsApi {
  int created = 0;
  @override
  Future<String> create() async => 'new-${++created}';
}

class _FakeExporter implements ConversationExporter {
  final List<({String fileName, String markdown})> exported = [];
  Object? error;
  @override
  Future<void> export({
    required String fileName,
    required String markdown,
  }) async {
    final e = error;
    if (e != null) throw e;
    exported.add((fileName: fileName, markdown: markdown));
  }
}

final _userProvider = StateProvider<String?>((_) => 'user-1');

ChatSessionSummary _session(String id, {String? preview}) => ChatSessionSummary(
  id: id,
  createdAt: DateTime.utc(2026, 10, 3, 21, 5),
  preview: preview,
);

List<ChatMessage> _conversation() => [
  ChatMessage.user(id: 0, text: 'Who invented it?'),
  ChatMessage(
    id: 1,
    role: ChatRole.assistant,
    text: 'Dr. Quartermain.[[chunk:c1]]',
    retrievalDone: true,
    retrievedChunkIds: const {'c1'},
    citedDocuments: const {'c1': 'd1'},
    citationTitles: const {'d1': 'zanzibar.txt'},
  ),
];

({
  ProviderContainer c,
  _FakeHistory history,
  _FakeStream stream,
  _FakeSessions sessions,
  _FakeExporter exporter,
})
_setup() {
  final history = _FakeHistory();
  final stream = _FakeStream();
  final sessions = _FakeSessions();
  final exporter = _FakeExporter();
  final c = ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(_userProvider)),
      chatHistoryApiProvider.overrideWithValue(history),
      chatStreamApiProvider.overrideWithValue(stream),
      chatSessionsApiProvider.overrideWithValue(sessions),
      conversationExporterProvider.overrideWithValue(exporter),
    ],
  );
  addTearDown(c.dispose);
  c.listen(chatControllerProvider, (_, _) {});
  return (
    c: c,
    history: history,
    stream: stream,
    sessions: sessions,
    exporter: exporter,
  );
}

ChatState _chat(ProviderContainer c) => c.read(chatControllerProvider);
ChatController _ctl(ProviderContainer c) =>
    c.read(chatControllerProvider.notifier);
Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  group('reopening a past conversation', () {
    test('shows its messages, with citations resolved, and its date', () async {
      final (:c, :history, stream: _, sessions: _, exporter: _) = _setup();
      history.messagesBySession['s1'] = _conversation();

      final opening = _ctl(c).openSession(_session('s1'));
      expect(_chat(c).loading, isTrue);
      expect(_chat(c).sessionId, 's1');
      expect(_chat(c).messages, isEmpty);

      await opening;

      expect(_chat(c).loading, isFalse);
      expect(_chat(c).loadError, isNull);
      expect(_chat(c).messages, hasLength(2));
      expect(_chat(c).messages.last.citationTitles, {'d1': 'zanzibar.txt'});
      expect(_chat(c).startedAt, DateTime.utc(2026, 10, 3, 21, 5));
    });

    test(
      'a follow-up goes to the SAME conversation — no new session',
      () async {
        final (:c, :history, :stream, :sessions, exporter: _) = _setup();
        history.messagesBySession['s1'] = _conversation();
        await _ctl(c).openSession(_session('s1'));

        final turn = _ctl(c).send('And its weakness?');
        await _tick();
        stream.turns.single.controller.add(const ChatDone());
        await turn;

        expect(sessions.created, 0);
        expect(stream.turns.single.sessionId, 's1');
        expect(_chat(c).messages, hasLength(4));
        expect(
          _chat(c).messages.map((m) => m.id).toSet(),
          hasLength(4),
          reason: 'new messages must not reuse a restored message id',
        );
      },
    );

    test('a failure is reported, and Retry loads it', () async {
      final (:c, :history, stream: _, sessions: _, exporter: _) = _setup();
      history.messagesBySession['s1'] = _conversation();
      history.messagesError = const NetworkUnreachableException();

      await _ctl(c).openSession(_session('s1'));
      expect(_chat(c).loadError, isA<NetworkUnreachableException>());
      expect(_chat(c).loading, isFalse);
      expect(_chat(c).messages, isEmpty);

      history.messagesError = null;
      await _ctl(c).reloadHistory();

      expect(_chat(c).loadError, isNull);
      expect(_chat(c).messages, hasLength(2));
    });

    test(
      'a conversation that no longer exists says so in plain words',
      () async {
        final (:c, :history, stream: _, sessions: _, exporter: _) = _setup();
        history.messagesError = const RequestRejectedException(
          'Chat session not found',
          code: 'not_found',
        );

        await _ctl(c).openSession(_session('gone'));

        expect(
          _chat(c).loadError!.message,
          'This conversation no longer exists.',
        );
      },
    );

    test('questions are ignored while it is still loading', () async {
      final (:c, :history, :stream, sessions: _, exporter: _) = _setup();
      history.messagesGate = Completer<void>();
      history.messagesBySession['s1'] = _conversation();
      final opening = _ctl(c).openSession(_session('s1'));

      await _ctl(c).send('too early');
      expect(stream.turns, isEmpty);

      history.messagesGate!.complete();
      await opening;
      expect(_chat(c).messages, hasLength(2));
    });

    test('replaces a running turn, releasing its connection', () async {
      final (:c, :history, :stream, sessions: _, exporter: _) = _setup();
      history.messagesBySession['s1'] = _conversation();
      unawaited(_ctl(c).send('live question'));
      await _tick();
      final live = stream.turns.single;

      await _ctl(c).openSession(_session('s1'));
      live.controller.add(const ChatToken('late words'));
      await _tick();

      expect(live.cancelled, isTrue);
      expect(_chat(c).messages, hasLength(2));
      expect(
        _chat(c).messages.map((m) => m.text).join(),
        isNot(contains('late')),
      );
    });

    test('a slow load for one conversation never lands on the next one you '
        'opened', () async {
      final (:c, :history, stream: _, sessions: _, exporter: _) = _setup();
      history.messagesBySession['slow'] = [
        ChatMessage.user(id: 0, text: 'slow one'),
      ];
      history.messagesBySession['fast'] = _conversation();
      final slowGate = Completer<void>();
      history.messagesGate = slowGate;
      final first = _ctl(c).openSession(_session('slow'));
      await _tick();

      // Open another conversation while the first is still loading…
      history.messagesGate = null;
      await _ctl(c).openSession(_session('fast'));
      expect(_chat(c).messages.first.text, 'Who invented it?');

      // …and only now does the slow response arrive.
      slowGate.complete();
      await first;
      await _tick();

      expect(_chat(c).sessionId, 'fast');
      expect(
        _chat(c).messages.first.text,
        'Who invented it?',
        reason: "the slow conversation's late response replaced the new one",
      );
    });

    test('a different user signing in sees no conversation', () async {
      final (:c, :history, stream: _, sessions: _, exporter: _) = _setup();
      history.messagesBySession['s1'] = _conversation();
      await _ctl(c).openSession(_session('s1'));

      c.read(_userProvider.notifier).state = 'user-2';
      await _tick();

      expect(_chat(c).messages, isEmpty);
      expect(_chat(c).sessionId, isNull);
    });
  });

  group('the list of past conversations', () {
    test('loads most recent first, as the server returns it', () async {
      final (:c, :history, stream: _, sessions: _, exporter: _) = _setup();
      history.sessions = [
        _session('b', preview: 'second'),
        _session('a', preview: 'first'),
      ];

      final list = await c.read(chatSessionsListProvider.future);

      expect(list.map((s) => s.id), ['b', 'a']);
    });

    test('a failure is surfaced, and refresh recovers', () async {
      final (:c, :history, stream: _, sessions: _, exporter: _) = _setup();
      history.listError = const NetworkUnreachableException();
      c.listen(chatSessionsListProvider, (_, _) {});
      await expectLater(
        c.read(chatSessionsListProvider.future),
        throwsA(isA<NetworkUnreachableException>()),
      );

      history.listError = null;
      history.sessions = [_session('a')];
      await c.read(chatSessionsListProvider.notifier).refresh();

      expect(c.read(chatSessionsListProvider).requireValue.single.id, 'a');
    });

    test(
      'refresh keeps the old list on screen until the new one arrives',
      () async {
        final (:c, :history, stream: _, sessions: _, exporter: _) = _setup();
        history.sessions = [_session('a')];
        c.listen(chatSessionsListProvider, (_, _) {});
        await c.read(chatSessionsListProvider.future);

        history.sessions = [_session('b'), _session('a')];
        final refreshing = c.read(chatSessionsListProvider.notifier).refresh();
        expect(c.read(chatSessionsListProvider).valueOrNull, hasLength(1));
        await refreshing;

        expect(c.read(chatSessionsListProvider).requireValue, hasLength(2));
      },
    );

    test('delete removes it from the server and from the list', () async {
      final (:c, :history, stream: _, sessions: _, exporter: _) = _setup();
      history.sessions = [_session('a'), _session('b')];
      c.listen(chatSessionsListProvider, (_, _) {});
      await c.read(chatSessionsListProvider.future);

      final error = await c.read(chatSessionsListProvider.notifier).delete('a');

      expect(error, isNull);
      expect(history.deleted, ['a']);
      expect(c.read(chatSessionsListProvider).requireValue.map((s) => s.id), [
        'b',
      ]);
    });

    test('"already gone" counts as deleted', () async {
      final (:c, :history, stream: _, sessions: _, exporter: _) = _setup();
      history.sessions = [_session('a')];
      history.deleteError = const RequestRejectedException(
        'Chat session not found',
        code: 'not_found',
      );
      c.listen(chatSessionsListProvider, (_, _) {});
      await c.read(chatSessionsListProvider.future);

      final error = await c.read(chatSessionsListProvider.notifier).delete('a');

      expect(error, isNull);
      expect(c.read(chatSessionsListProvider).requireValue, isEmpty);
    });

    test(
      'a failed delete returns the reason and leaves the conversation',
      () async {
        final (:c, :history, stream: _, sessions: _, exporter: _) = _setup();
        history.sessions = [_session('a')];
        history.deleteError = const NetworkUnreachableException();
        c.listen(chatSessionsListProvider, (_, _) {});
        await c.read(chatSessionsListProvider.future);

        final error = await c
            .read(chatSessionsListProvider.notifier)
            .delete('a');

        expect(error, isA<NetworkUnreachableException>());
        expect(c.read(chatSessionsListProvider).requireValue, hasLength(1));
      },
    );

    test('deleting the conversation that is open clears the chat', () async {
      final (:c, :history, stream: _, sessions: _, exporter: _) = _setup();
      history.sessions = [_session('s1')];
      history.messagesBySession['s1'] = _conversation();
      await _ctl(c).openSession(_session('s1'));
      c.listen(chatSessionsListProvider, (_, _) {});
      await c.read(chatSessionsListProvider.future);

      await c.read(chatSessionsListProvider.notifier).delete('s1');

      expect(_chat(c).messages, isEmpty);
      expect(_chat(c).sessionId, isNull);
    });

    test(
      'deleting a different conversation leaves the open chat alone',
      () async {
        final (:c, :history, stream: _, sessions: _, exporter: _) = _setup();
        history.sessions = [_session('s1'), _session('other')];
        history.messagesBySession['s1'] = _conversation();
        await _ctl(c).openSession(_session('s1'));
        c.listen(chatSessionsListProvider, (_, _) {});
        await c.read(chatSessionsListProvider.future);

        await c.read(chatSessionsListProvider.notifier).delete('other');

        expect(_chat(c).sessionId, 's1');
        expect(_chat(c).messages, hasLength(2));
      },
    );
  });

  group('exporting', () {
    test(
      'the open conversation is written as Markdown under a stable name',
      () async {
        final (:c, :history, stream: _, sessions: _, :exporter) = _setup();
        history.messagesBySession['abcdef12-3456'] = _conversation();
        await _ctl(c).openSession(_session('abcdef12-3456'));

        await c.read(chatExportServiceProvider).exportOpenConversation();

        final out = exporter.exported.single;
        expect(out.fileName, 'cerebro-chat-abcdef12.md');
        expect(out.markdown, startsWith('# Chat — '));
        expect(out.markdown, contains('## You\n\nWho invented it?'));
        expect(out.markdown, contains('Dr. Quartermain.[1]'));
        expect(out.markdown, contains('- [1] zanzibar.txt'));
        expect(out.markdown, isNot(contains('[[chunk:')));
      },
    );

    test('a past conversation is fetched fresh and exported', () async {
      final (:c, :history, stream: _, sessions: _, :exporter) = _setup();
      history.messagesBySession['s9'] = _conversation();

      await c.read(chatExportServiceProvider).exportSession(_session('s9'));

      expect(exporter.exported.single.fileName, 'cerebro-chat-s9.md');
      expect(
        exporter.exported.single.markdown,
        contains('Dr. Quartermain.[1]'),
      );
    });

    test('nothing to export yet is said plainly', () async {
      final (:c, history: _, stream: _, sessions: _, :exporter) = _setup();

      await expectLater(
        c.read(chatExportServiceProvider).exportOpenConversation(),
        throwsA(isA<UnknownApiException>()),
      );
      expect(exporter.exported, isEmpty);
    });

    test(
      'a failure to fetch is the API error, with nothing exported',
      () async {
        final (:c, :history, stream: _, sessions: _, :exporter) = _setup();
        history.messagesError = const NetworkUnreachableException();

        await expectLater(
          c.read(chatExportServiceProvider).exportSession(_session('s1')),
          throwsA(isA<NetworkUnreachableException>()),
        );
        expect(exporter.exported, isEmpty);
      },
    );

    test('a failure to write or share becomes a plain message', () async {
      final (:c, :history, stream: _, sessions: _, :exporter) = _setup();
      history.messagesBySession['s1'] = _conversation();
      exporter.error = StateError('disk full');

      await expectLater(
        c.read(chatExportServiceProvider).exportSession(_session('s1')),
        throwsA(
          isA<UnknownApiException>().having(
            (e) => e.message,
            'message',
            "Couldn't export this conversation.",
          ),
        ),
      );
    });
  });
}
