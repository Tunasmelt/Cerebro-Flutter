// What the graph pulses: a live retrieval, a replayed conversation, and the
// plumbing from the chat controller.
import 'dart:async';
import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/chat/data/chat_sessions_list.dart';

import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/chat/data/chat_controller.dart';
import 'package:cerebro_mobile/features/chat/data/chat_history_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_message.dart';
import 'package:cerebro_mobile/features/chat/data/chat_sessions_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_client.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_event.dart';
import 'package:cerebro_mobile/features/graph/data/graph_pulse.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Turn {
  final controller = StreamController<ChatStreamEvent>();
}

class _Stream implements ChatStreamApi {
  final turns = <_Turn>[];
  @override
  Stream<ChatStreamEvent> stream({
    required String sessionId,
    required String query,
    String? documentId,
  }) {
    final t = _Turn();
    turns.add(t);
    return t.controller.stream;
  }
}

class _Sessions implements ChatSessionsApi {
  @override
  Future<String> create() async => 's1';
}

class _History implements ChatHistoryApi {
  final messages_ = <ChatMessage>[];
  bool fail = false;
  @override
  Future<List<ChatSessionSummary>> list() async => const [];
  @override
  Future<ChatHistory> messages(String id) async => fail
      ? throw const NetworkUnreachableException()
      : ChatHistory(messages: List.of(messages_));
  @override
  Future<void> delete(String id) async {}
}

({ProviderContainer c, _Stream stream, _History history, List<GraphPulse> log})
_setup({String? user = 'u1'}) {
  final stream = _Stream();
  final history = _History();
  final c = ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWithValue(user),
      chatStreamApiProvider.overrideWithValue(stream),
      chatSessionsApiProvider.overrideWithValue(_Sessions()),
      chatHistoryApiProvider.overrideWithValue(history),
    ],
  );
  addTearDown(c.dispose);
  final log = <GraphPulse>[];
  c.listen(graphPulseProvider, (_, next) {
    final p = next.pulse;
    if (p != null && (log.isEmpty || log.last.key != p.key)) log.add(p);
  });
  c.listen(chatControllerProvider, (_, _) {});
  return (c: c, stream: stream, history: history, log: log);
}

GraphPulseController _pulse(ProviderContainer c) =>
    c.read(graphPulseProvider.notifier);
GraphPulseState _state(ProviderContainer c) => c.read(graphPulseProvider);
Future<void> _tick([int ms = 5]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

ChatMessage _answer(int id, List<String> docs) => ChatMessage(
  id: id,
  role: ChatRole.assistant,
  retrievalDone: true,
  retrievedDocumentIds: docs,
);

void main() {
  test(
    'New chat cancels all remaining replay steps and clears its pulse',
    () async {
      final (:c, stream: _, history: _, :log) = _setup();
      final done = _pulse(c).replay([
        ['old-a'],
        ['old-b'],
      ], gap: const Duration(milliseconds: 20));
      c.read(chatControllerProvider.notifier).newChat();
      await done;
      expect(_state(c).replaying, isFalse);
      expect(_state(c).pulse, isNull);
      expect(log.map((p) => p.documentIds), [
        ['old-a'],
      ]);
    },
  );

  test('deleting the active conversation cancels its replay', () async {
    final (:c, stream: _, :history, :log) = _setup();
    history.messages_.add(_answer(1, ['a']));
    await c
        .read(chatControllerProvider.notifier)
        .openSession(
          ChatSessionSummary(id: 's1', createdAt: DateTime.utc(2026)),
          replay: false,
        );
    final done = _pulse(c).replay([
      ['a'],
      ['b'],
    ], gap: const Duration(milliseconds: 20));
    c.listen(chatSessionsListProvider, (_, _) {});
    await c.read(chatSessionsListProvider.future);
    expect(
      await c.read(chatSessionsListProvider.notifier).delete('s1'),
      isNull,
    );
    await done;
    expect(c.read(chatControllerProvider).sessionId, isNull);
    expect(_state(c).pulse, isNull);
    expect(_state(c).replaying, isFalse);
    expect(log.map((p) => p.documentIds), [
      ['a'],
    ]);
  });

  test(
    'a successful history retry replays; opt-out remains respected',
    () async {
      for (final enabled in [true, false]) {
        final (:c, stream: _, :history, :log) = _setup();
        history.messages_.add(_answer(1, ['d1']));
        history.fail = true;
        final chat = c.read(chatControllerProvider.notifier);
        await chat.openSession(
          ChatSessionSummary(id: 's1', createdAt: DateTime.utc(2026)),
          replay: enabled,
        );
        expect(c.read(chatControllerProvider).loadError, isNotNull);
        history.fail = false;
        await chat.reloadHistory();
        expect(c.read(chatControllerProvider).loadError, isNull);
        expect(log.length, enabled ? 1 : 0);
        if (enabled) expect(log.single.documentIds, ['d1']);
        _pulse(c).clear();
      }
    },
  );

  group('a live retrieval pulses exactly the documents it reported', () {
    test('every document in the payload, no more, no fewer', () async {
      final (:c, :stream, history: _, :log) = _setup();
      final turn = _pulse(c); // keep provider alive
      expect(turn, isNotNull);

      final sending = c.read(chatControllerProvider.notifier).send('hi');
      await _tick();
      stream.turns.single.controller.add(
        const ChatRetrieval(
          chunkIds: ['c1', 'c2', 'c3'],
          documentIds: ['d1', 'd2', 'd3'],
        ),
      );
      await _tick();

      expect(log, hasLength(1));
      expect(log.single.documentIds, ['d1', 'd2', 'd3']);

      stream.turns.single.controller.add(const ChatDone());
      await stream.turns.single.controller.close();
      await sending;
    });

    test(
      'the pulse is there as soon as retrieval is, before any token',
      () async {
        final (:c, :stream, history: _, :log) = _setup();
        final sending = c.read(chatControllerProvider.notifier).send('hi');
        await _tick();
        stream.turns.single.controller.add(
          const ChatRetrieval(chunkIds: ['c1'], documentIds: ['d1']),
        );
        await _tick();

        // Still streaming — no token, no done — and the graph already pulsed.
        expect(c.read(chatControllerProvider).busy, isTrue);
        expect(c.read(chatControllerProvider).messages.last.text, isEmpty);
        expect(log.single.documentIds, ['d1']);

        await stream.turns.single.controller.close();
        await sending;
      },
    );

    test('the same documents listed twice pulse once each', () async {
      final (:c, :stream, history: _, :log) = _setup();
      final sending = c.read(chatControllerProvider.notifier).send('hi');
      await _tick();
      stream.turns.single.controller.add(
        const ChatRetrieval(
          chunkIds: ['c1', 'c2', 'c3'],
          documentIds: ['d1', 'd1', 'd2'],
        ),
      );
      await _tick();
      expect(log.single.documentIds, ['d1', 'd2']);
      await stream.turns.single.controller.close();
      await sending;
    });

    test('a retrieval that found nothing pulses nothing', () async {
      final (:c, :stream, history: _, :log) = _setup();
      final sending = c.read(chatControllerProvider.notifier).send('hi');
      await _tick();
      stream.turns.single.controller.add(
        const ChatRetrieval(chunkIds: [], documentIds: []),
      );
      await _tick();
      expect(log, isEmpty);
      expect(_state(c).pulse, isNull);
      await stream.turns.single.controller.close();
      await sending;
    });

    test('the message remembers which documents it drew from', () async {
      final (:c, :stream, history: _, log: _) = _setup();
      final sending = c.read(chatControllerProvider.notifier).send('hi');
      await _tick();
      stream.turns.single.controller.add(
        const ChatRetrieval(chunkIds: ['c1', 'c2'], documentIds: ['d2', 'd1']),
      );
      await _tick();
      expect(
        c.read(chatControllerProvider).messages.last.retrievedDocumentIds,
        ['d2', 'd1'],
      );
      await stream.turns.single.controller.close();
      await sending;
    });

    test('asking again restarts the pulse even for the same documents', () {
      final (:c, stream: _, history: _, :log) = _setup();
      _pulse(c).trigger(['d1', 'd2']);
      _pulse(c).trigger(['d1', 'd2']);
      expect(log, hasLength(2));
      expect(
        log[0].key,
        isNot(log[1].key),
        reason: 'the animation would not restart',
      );
    });

    test('blank ids are not documents', () {
      final (:c, stream: _, history: _, :log) = _setup();
      _pulse(c).trigger(['', 'd1', '']);
      expect(log.single.documentIds, ['d1']);
    });
  });

  group('replaying a past conversation', () {
    test('plays each answer\'s retrieval in the order it happened, one at a '
        'time', () async {
      final (:c, stream: _, history: _, :log) = _setup();
      final done = _pulse(c).replay([
        ['a', 'b'],
        ['c'],
        ['a', 'd'],
      ], gap: const Duration(milliseconds: 20));

      await _tick(8);
      expect(log.map((p) => p.documentIds), [
        ['a', 'b'],
      ], reason: 'the second pulse came too early');
      expect(_state(c).replaying, isTrue);

      await done;
      expect(log.map((p) => p.documentIds), [
        ['a', 'b'],
        ['c'],
        ['a', 'd'],
      ]);
      expect(_state(c).replaying, isFalse);
    });

    test('a replay of nothing is not a replay', () async {
      final (:c, stream: _, history: _, :log) = _setup();
      await _pulse(c).replay(const []);
      expect(log, isEmpty);
      expect(_state(c).replaying, isFalse);
    });

    test('a live retrieval takes over from a replay still playing', () async {
      final (:c, stream: _, history: _, :log) = _setup();
      final done = _pulse(c).replay([
        ['a'],
        ['b'],
        ['c'],
      ], gap: const Duration(milliseconds: 30));
      await _tick(8);
      _pulse(c).trigger(['live']);
      await done;
      await _tick(60);

      expect(
        log.map((p) => p.documentIds),
        [
          ['a'],
          ['live'],
        ],
        reason: 'the replay carried on over the live pulse',
      );
      expect(_state(c).replaying, isFalse);
    });

    test('starting a new replay cancels the old one', () async {
      final (:c, stream: _, history: _, :log) = _setup();
      final first = _pulse(c).replay([
        ['a'],
        ['b'],
      ], gap: const Duration(milliseconds: 30));
      await _tick(8);
      final second = _pulse(c).replay([
        ['x'],
      ], gap: const Duration(milliseconds: 5));
      await Future.wait([first, second]);
      await _tick(60);

      expect(log.map((p) => p.documentIds), [
        ['a'],
        ['x'],
      ]);
    });

    test('stopReplay stops it, and what already pulsed runs out', () async {
      final (:c, stream: _, history: _, :log) = _setup();
      final done = _pulse(c).replay([
        ['a'],
        ['b'],
      ], gap: const Duration(milliseconds: 30));
      await _tick(8);
      _pulse(c).stopReplay();
      await done;
      await _tick(60);

      expect(log.map((p) => p.documentIds), [
        ['a'],
      ]);
      expect(_state(c).replaying, isFalse);
      expect(_state(c).pulse?.documentIds, ['a']);
    });

    test('a different user starts with nothing pulsing or replaying', () async {
      final user = StateProvider<String?>((_) => 'u1');
      final c = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => ref.watch(user)),
        ],
      );
      addTearDown(c.dispose);
      c.listen(graphPulseProvider, (_, _) {});
      final done = _pulse(c).replay([
        ['a'],
        ['b'],
      ], gap: const Duration(milliseconds: 30));
      await _tick(8);
      c.read(user.notifier).state = 'u2';
      await done;
      await _tick(60);
      expect(_state(c).pulse, isNull);
      expect(_state(c).replaying, isFalse);
    });
  });

  group('replaySteps', () {
    test('one step per answer that retrieved something, in order', () {
      final steps = replaySteps([
        ChatMessage.user(id: 0, text: 'q1'),
        _answer(1, ['a', 'b']),
        ChatMessage.user(id: 2, text: 'q2'),
        _answer(3, const []),
        ChatMessage.user(id: 4, text: 'q3'),
        _answer(5, ['c']),
      ]);
      expect(steps, [
        ['a', 'b'],
        ['c'],
      ]);
    });

    test('nothing to replay for a conversation that retrieved nothing', () {
      expect(replaySteps([ChatMessage.user(id: 0, text: 'q')]), isEmpty);
      expect(replaySteps(const []), isEmpty);
    });
  });

  group('a reopened conversation replays what pulsed live', () {
    test('stored document ids are read from the history row', () {
      final m = ChatMessage.fromHistory({
        'role': 'assistant',
        'content': 'x',
        'retrieved_chunk_ids': ['c1', 'c2'],
        'retrieved_document_ids': ['d1', 7, null, '', 'd2'],
      }, id: 1)!;
      expect(m.retrievedDocumentIds, ['d1', 'd2']);
    });

    test('a row with no stored document ids replays nothing, not an error', () {
      final m = ChatMessage.fromHistory({
        'role': 'assistant',
        'content': 'x',
      }, id: 1)!;
      expect(m.retrievedDocumentIds, isEmpty);
      expect(replaySteps([m]), isEmpty);
    });

    test('opening from Chat History automatically starts replay', () async {
      final (:c, stream: _, :history, :log) = _setup();
      history.messages_.add(_answer(1, ['d1', 'd2']));
      await c
          .read(chatControllerProvider.notifier)
          .openSession(
            ChatSessionSummary(id: 's1', createdAt: DateTime.utc(2026)),
          );
      expect(log.map((p) => p.documentIds), [
        ['d1', 'd2'],
      ]);
      expect(_state(c).replaying, isTrue);
      _pulse(c).stopReplay();
    });

    test('open a stored conversation and replay it: the same documents, in '
        'order', () async {
      final (:c, stream: _, :history, :log) = _setup();
      history.messages_.addAll([
        ChatMessage.user(id: 0, text: 'q1'),
        _answer(1, ['d1', 'd2']),
        ChatMessage.user(id: 2, text: 'q2'),
        _answer(3, ['d3']),
      ]);

      final chat = c.read(chatControllerProvider.notifier);
      await chat.openSession(
        ChatSessionSummary(id: 's1', createdAt: DateTime.utc(2026)),
        replay: false,
      );
      await _pulse(c).replay(
        replaySteps(c.read(chatControllerProvider).messages),
        gap: const Duration(milliseconds: 5),
      );

      expect(log.map((p) => p.documentIds), [
        ['d1', 'd2'],
        ['d3'],
      ]);
    });
  });
}
