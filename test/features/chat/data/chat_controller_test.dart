// The chat controller against a controllable fake stream: no network.
import 'dart:async';

import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/chat/data/chat_controller.dart';
import 'package:cerebro_mobile/features/chat/data/chat_message.dart';
import 'package:cerebro_mobile/features/chat/data/chat_sessions_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_client.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// One call to `stream()`, driven by the test.
class _Turn {
  _Turn(this.sessionId, this.query);
  final String sessionId;
  final String query;
  bool cancelled = false;
  late final StreamController<ChatStreamEvent> controller =
      StreamController<ChatStreamEvent>(onCancel: () => cancelled = true);

  void add(ChatStreamEvent e) => controller.add(e);
  void fail(AppException e) => controller.addError(e);
  Future<void> end() => controller.close();
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
  Object? error;
  Completer<void>? gate;

  @override
  Future<String> create() async {
    created++;
    await gate?.future;
    final e = error;
    if (e != null) throw e;
    return 'session-$created';
  }
}

final _userProvider = StateProvider<String?>((_) => 'user-1');

({ProviderContainer c, _FakeStream stream, _FakeSessions sessions}) _setup() {
  final stream = _FakeStream();
  final sessions = _FakeSessions();
  final c = ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(_userProvider)),
      chatStreamApiProvider.overrideWithValue(stream),
      chatSessionsApiProvider.overrideWithValue(sessions),
    ],
  );
  addTearDown(c.dispose);
  c.listen(chatControllerProvider, (_, _) {});
  return (c: c, stream: stream, sessions: sessions);
}

ChatState _state(ProviderContainer c) => c.read(chatControllerProvider);
ChatController _ctl(ProviderContainer c) =>
    c.read(chatControllerProvider.notifier);
ChatMessage _answer(ProviderContainer c) => _state(c).messages.last;

Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 5));

const _retrieval = ChatRetrieval(chunkIds: ['c1', 'c2'], documentIds: ['d1']);

void main() {
  group('a normal turn', () {
    test(
      'shows the question and a pending answer at once, then fills it in',
      () async {
        final (:c, :stream, :sessions) = _setup();

        final turn = _ctl(c).send('  What is Cerebro?  ');
        expect(_state(c).messages, hasLength(2));
        expect(_state(c).messages[0].role, ChatRole.user);
        expect(
          _state(c).messages[0].text,
          'What is Cerebro?',
          reason: 'trimmed',
        );
        expect(_answer(c).isStreaming, isTrue);
        expect(_state(c).busy, isTrue);

        await _tick();
        final t = stream.turns.single;
        expect(t.sessionId, 'session-1');
        expect(t.query, 'What is Cerebro?');

        t.add(const ChatHeartbeat());
        t.add(_retrieval);
        await _tick();
        expect(_answer(c).retrievalDone, isTrue);
        expect(_answer(c).retrievedChunkIds, {'c1', 'c2'});
        expect(_answer(c).text, '');

        t.add(const ChatToken('Cerebro is '));
        t.add(const ChatToken('a memory graph.'));
        await _tick();
        expect(_answer(c).text, 'Cerebro is a memory graph.');
        expect(_answer(c).isStreaming, isTrue);

        t.add(const ChatCitation(chunkId: 'c1', documentId: 'd1'));
        t.add(const ChatDone());
        await turn;

        expect(_answer(c).status, ChatMessageStatus.complete);
        expect(_answer(c).citedDocuments, {'c1': 'd1'});
        expect(_state(c).busy, isFalse);
      },
    );

    test(
      'markers split across tokens accumulate untouched in the raw text',
      () async {
        final (:c, :stream, sessions: _) = _setup();
        final turn = _ctl(c).send('q');
        await _tick();
        final t = stream.turns.single;
        for (final piece in ['Yes.', '[[ch', 'unk:c', '1]]']) {
          t.add(ChatToken(piece));
        }
        t.add(const ChatDone());
        await turn;

        expect(_answer(c).text, 'Yes.[[chunk:c1]]');
      },
    );

    test('a second question reuses the conversation', () async {
      final (:c, :stream, :sessions) = _setup();
      var turn = _ctl(c).send('one');
      await _tick();
      stream.turns[0].add(const ChatDone());
      await turn;

      turn = _ctl(c).send('two');
      await _tick();
      stream.turns[1].add(const ChatDone());
      await turn;

      expect(sessions.created, 1);
      expect(stream.turns.map((t) => t.sessionId), ['session-1', 'session-1']);
      expect(_state(c).messages, hasLength(4));
    });

    test(
      'blank input and a question while one is running are ignored',
      () async {
        final (:c, :stream, :sessions) = _setup();
        await _ctl(c).send('   ');
        expect(_state(c).messages, isEmpty);

        unawaited(_ctl(c).send('first'));
        await _tick();
        await _ctl(c).send('second'); // busy: ignored
        expect(_state(c).messages, hasLength(2));
        expect(stream.turns, hasLength(1));
        expect(sessions.created, 1);
      },
    );

    test(
      'retrieval that finds nothing is its own recognisable state',
      () async {
        final (:c, :stream, sessions: _) = _setup();
        final turn = _ctl(c).send('q');
        await _tick();
        final t = stream.turns.single;
        t.add(const ChatRetrieval(chunkIds: [], documentIds: []));
        await _tick();
        expect(_answer(c).retrievalFoundNothing, isTrue);

        t.add(const ChatToken('I could not find anything.'));
        t.add(const ChatDone());
        await turn;
        expect(_answer(c).retrievalFoundNothing, isTrue);
      },
    );

    test('before retrieval reports, "found nothing" is NOT claimed', () async {
      final (:c, sessions: _, stream: _) = _setup();
      unawaited(_ctl(c).send('q'));
      await _tick();
      expect(_answer(c).retrievalFoundNothing, isFalse);
    });
  });

  group('when a turn fails', () {
    test('an error event keeps the partial text and shows plain words, never '
        'the raw server message', () async {
      final (:c, :stream, sessions: _) = _setup();
      final turn = _ctl(c).send('q');
      await _tick();
      final t = stream.turns.single;
      t.add(_retrieval);
      t.add(const ChatToken('Partial answer'));
      t.add(
        const ChatError(code: 'chat_turn_failed', rawMessage: 'ReadTimeout'),
      );
      await turn;

      final a = _answer(c);
      expect(a.status, ChatMessageStatus.failed);
      expect(a.text, 'Partial answer');
      expect(a.error!.message, isNot(contains('ReadTimeout')));
      expect(_state(c).busy, isFalse);
    });

    test(
      'a connection failure mid-answer is failed, with its own message',
      () async {
        final (:c, :stream, sessions: _) = _setup();
        final turn = _ctl(c).send('q');
        await _tick();
        final t = stream.turns.single;
        t.add(const ChatToken('abc'));
        t.fail(const NetworkUnreachableException());
        await turn;

        expect(_answer(c).status, ChatMessageStatus.failed);
        expect(_answer(c).text, 'abc');
        expect(_answer(c).error, isA<NetworkUnreachableException>());
      },
    );

    test('failing to start the conversation fails the turn; the next try '
        'starts it again', () async {
      final (:c, :stream, :sessions) = _setup();
      sessions.error = const NetworkUnreachableException();
      await _ctl(c).send('q');

      expect(_answer(c).status, ChatMessageStatus.failed);
      expect(_answer(c).error, isA<NetworkUnreachableException>());
      expect(stream.turns, isEmpty);
      expect(_state(c).sessionId, isNull);

      sessions.error = null;
      final turn = _ctl(c).retry();
      await _tick();
      expect(stream.turns, hasLength(1));
      stream.turns.single.add(const ChatDone());
      await turn;
      expect(_answer(c).status, ChatMessageStatus.complete);
    });

    test(
      'retry re-asks the same question in place of the failed answer',
      () async {
        final (:c, :stream, sessions: _) = _setup();
        var turn = _ctl(c).send('Why?');
        await _tick();
        stream.turns[0].add(const ChatError(code: 'x', rawMessage: ''));
        await turn;
        expect(_answer(c).status, ChatMessageStatus.failed);

        turn = _ctl(c).retry();
        await _tick();
        expect(
          _state(c).messages,
          hasLength(2),
          reason: 'no duplicate question',
        );
        expect(stream.turns[1].query, 'Why?');
        expect(stream.turns[1].sessionId, stream.turns[0].sessionId);
        expect(_answer(c).isStreaming, isTrue);
        expect(
          _answer(c).text,
          '',
          reason: 'a clean slate, not the old partial',
        );

        stream.turns[1].add(const ChatToken('Because.'));
        stream.turns[1].add(const ChatDone());
        await turn;
        expect(_answer(c).text, 'Because.');
        expect(_answer(c).status, ChatMessageStatus.complete);
      },
    );

    test('retry does nothing unless the last answer failed', () async {
      final (:c, :stream, sessions: _) = _setup();
      final turn = _ctl(c).send('q');
      await _tick();
      stream.turns.single.add(const ChatDone());
      await turn;

      await _ctl(c).retry();
      expect(stream.turns, hasLength(1));
      expect(_answer(c).status, ChatMessageStatus.complete);
    });
  });

  group('Stop', () {
    test('keeps what has arrived, releases the connection, and ignores '
        'anything that arrives after', () async {
      final (:c, :stream, sessions: _) = _setup();
      final turn = _ctl(c).send('q');
      await _tick();
      final t = stream.turns.single;
      t.add(_retrieval);
      t.add(const ChatToken('Half an ans'));
      await _tick();

      _ctl(c).stop();
      await turn;
      t.add(const ChatToken('wer that should not appear'));
      await _tick();

      expect(_answer(c).status, ChatMessageStatus.stopped);
      expect(_answer(c).text, 'Half an ans');
      expect(t.cancelled, isTrue);
      expect(_state(c).busy, isFalse);
    });

    test(
      'while the conversation is still being created: no stream starts',
      () async {
        final (:c, :stream, :sessions) = _setup();
        sessions.gate = Completer<void>();
        final turn = _ctl(c).send('q');
        await _tick();

        _ctl(c).stop();
        sessions.gate!.complete();
        await turn;
        await _tick();

        expect(stream.turns, isEmpty);
        expect(_answer(c).status, ChatMessageStatus.stopped);
      },
    );

    test('with nothing running it does nothing', () {
      final (:c, sessions: _, stream: _) = _setup();
      _ctl(c).stop();
      expect(_state(c).messages, isEmpty);
    });

    test('after Stop the next question works normally', () async {
      final (:c, :stream, sessions: _) = _setup();
      var turn = _ctl(c).send('one');
      await _tick();
      _ctl(c).stop();
      await turn;

      turn = _ctl(c).send('two');
      await _tick();
      stream.turns[1].add(const ChatToken('ok'));
      stream.turns[1].add(const ChatDone());
      await turn;

      expect(_answer(c).text, 'ok');
      expect(_answer(c).status, ChatMessageStatus.complete);
    });
  });

  group('starting over and changing user', () {
    test('new chat clears the conversation, releases a running stream, and '
        'the next question opens a new session', () async {
      final (:c, :stream, :sessions) = _setup();
      unawaited(_ctl(c).send('old'));
      await _tick();
      final old = stream.turns.single;

      _ctl(c).newChat();
      old.add(const ChatToken('late words from the old chat'));
      await _tick();
      expect(_state(c).messages, isEmpty);
      expect(old.cancelled, isTrue);

      final turn = _ctl(c).send('new');
      await _tick();
      stream.turns[1].add(const ChatDone());
      await turn;
      expect(sessions.created, 2);
      expect(stream.turns[1].sessionId, 'session-2');
    });

    test("a different user signing in starts with an empty conversation, and "
        "the previous user's late answer is dropped", () async {
      final (:c, :stream, sessions: _) = _setup();
      unawaited(_ctl(c).send('private question'));
      await _tick();
      final t = stream.turns.single;
      t.add(const ChatToken('private answer'));
      await _tick();

      c.read(_userProvider.notifier).state = 'user-2';
      await _tick();
      t.add(const ChatToken(' continues'));
      await _tick();

      expect(_state(c).messages, isEmpty);
      expect(_state(c).sessionId, isNull);
      expect(t.cancelled, isTrue);
    });
  });
}
