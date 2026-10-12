// The retrieval pulse on screen: which nodes light up, how it fades, and the
// two ways it starts — asking from the graph, and replaying a conversation.
import 'dart:async';

import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/chat/data/chat_controller.dart';
import 'package:cerebro_mobile/features/chat/data/chat_history_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_message.dart';
import 'package:cerebro_mobile/features/chat/data/chat_sessions_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_client.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_event.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/graph/data/graph_api.dart';
import 'package:cerebro_mobile/features/graph/data/graph_models.dart';
import 'package:cerebro_mobile/features/graph/data/graph_pulse.dart';
import 'package:cerebro_mobile/features/graph/presentation/graph_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../documents/fake_documents_repository.dart';

GraphNodeData _n(String id, double x, {String mime = 'text/plain'}) =>
    GraphNodeData(
      id: id,
      title: id,
      x: x,
      y: 0,
      mime: mime,
      status: 'ready',
      clusterId: 'c',
    );

class _Graph implements GraphApi {
  @override
  Future<List<GraphNodeData>> nodes() async => [
    _n('a', -1),
    _n('b', -0.3),
    _n('c', 0.4),
    _n('d', 1, mime: 'image/png'),
  ];
  @override
  Future<List<GraphEdgeData>> edges() async => const [];
  @override
  Future<List<DocumentChunk>> chunks(String documentId) async => const [];
}

class _Turn {
  final events = StreamController<ChatStreamEvent>();
  String query = '';
}

class _Stream implements ChatStreamApi {
  final turns = <_Turn>[];
  @override
  Stream<ChatStreamEvent> stream({
    required String sessionId,
    required String query,
    String? documentId,
  }) {
    final t = _Turn()..query = query;
    turns.add(t);
    return t.events.stream;
  }
}

class _Sessions implements ChatSessionsApi {
  @override
  Future<String> create() async => 's-new';
}

class _History implements ChatHistoryApi {
  List<ChatSessionSummary> sessions = [];
  final byId = <String, List<ChatMessage>>{};
  Object? listError;
  Object? messagesError;
  @override
  Future<List<ChatSessionSummary>> list() async {
    if (listError != null) throw listError!;
    return List.of(sessions);
  }

  @override
  Future<ChatHistory> messages(String id) async {
    if (messagesError != null) throw messagesError!;
    return ChatHistory(messages: byId[id] ?? const []);
  }

  @override
  Future<void> delete(String id) async {}
}

class _Rig {
  final stream = _Stream();
  final history = _History();
}

Future<void> _frames(WidgetTester tester, [int n = 4]) async {
  await tester.pump();
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<_Rig> _pump(WidgetTester tester) async {
  final rig = _Rig();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('u1'),
        graphApiProvider.overrideWithValue(_Graph()),
        chatStreamApiProvider.overrideWithValue(rig.stream),
        chatSessionsApiProvider.overrideWithValue(_Sessions()),
        chatHistoryApiProvider.overrideWithValue(rig.history),
        documentsRepositoryProvider.overrideWithValue(
          FakeDocumentsRepository(documents: const []),
        ),
      ],
      child: MaterialApp(theme: AppTheme.dark, home: const GraphScreen()),
    ),
  );
  await _frames(tester);
  return rig;
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GraphScreen)));

GraphPulseController _pulse(WidgetTester tester) =>
    _container(tester).read(graphPulseProvider.notifier);

Finder _ring(String id) => find.byKey(Key('graph_pulse_$id'));

/// The ids of the nodes whose pulse ring is showing.
Set<String> _pulsing(WidgetTester tester) => {
  for (final id in ['a', 'b', 'c', 'd', 'ghost'])
    if (_ring(id).evaluate().isNotEmpty) id,
};

double _ringWidth(WidgetTester tester, String id) =>
    tester.getSize(_ring(id)).width;

double _dotWidth(WidgetTester tester, String id) =>
    tester.getSize(find.byKey(Key('graph_node_$id'))).width;

void main() {
  group('a live retrieval', () {
    testWidgets('one haptic impact per retrieval, not per document', (
      tester,
    ) async {
      final impacts = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') impacts.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pump(tester);
      _pulse(tester).trigger(['a', 'c']);
      await tester.pump();
      expect(impacts, hasLength(1));
      expect(impacts.single.arguments, 'HapticFeedbackType.lightImpact');
      await tester.pump(pulseDuration);
    });

    testWidgets('lights up exactly the documents it names, and no others', (
      tester,
    ) async {
      await _pump(tester);
      expect(_pulsing(tester), isEmpty, reason: 'pulsing before any pulse');

      _pulse(tester).trigger(['a', 'c']);
      await tester.pump(const Duration(milliseconds: 100));

      expect(_pulsing(tester), {'a', 'c'});
    });

    testWidgets('fades and finishes: the rings go and the dots return to '
        'their size', (tester) async {
      await _pump(tester);
      final resting = _dotWidth(tester, 'a');

      _pulse(tester).trigger(['a']);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_dotWidth(tester, 'a'), greaterThan(resting), reason: 'no swell');
      expect(_ring('a'), findsOneWidget);

      await tester.pump(pulseDuration + const Duration(milliseconds: 100));
      expect(_pulsing(tester), isEmpty);
      expect(_dotWidth(tester, 'a'), resting);
    });

    testWidgets('the ring grows as it fades', (tester) async {
      await _pump(tester);
      _pulse(tester).trigger(['b']);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));
      final early = _ringWidth(tester, 'b');
      await tester.pump(const Duration(milliseconds: 800));
      final later = _ringWidth(tester, 'b');
      expect(later, greaterThan(early));
    });

    testWidgets('a dot swells most at the start and settles', (tester) async {
      await _pump(tester);
      _pulse(tester).trigger(['b']);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      final early = _dotWidth(tester, 'b');
      await tester.pump(const Duration(milliseconds: 1200));
      final later = _dotWidth(tester, 'b');
      expect(later, lessThan(early));
    });

    testWidgets('the same documents again restart the pulse', (tester) async {
      await _pump(tester);
      _pulse(tester).trigger(['a']);
      // The first frame only starts the clock; time passes on the next.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 1450));
      final fading = _ringWidth(tester, 'a');

      _pulse(tester).trigger(['a']);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_ring('a'), findsOneWidget);
      expect(
        _ringWidth(tester, 'a'),
        lessThan(fading),
        reason: 'the animation did not restart',
      );
    });

    testWidgets('a new pulse takes the light off the documents of the old '
        'one', (tester) async {
      await _pump(tester);
      _pulse(tester).trigger(['a', 'b']);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_pulsing(tester), {'a', 'b'});

      _pulse(tester).trigger(['c']);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_pulsing(tester), {'c'});
    });

    testWidgets('a document the graph does not have is ignored, not a crash', (
      tester,
    ) async {
      await _pump(tester);
      _pulse(tester).trigger(['ghost', 'a']);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(_pulsing(tester), {'a'});
    });

    testWidgets('a pulse does not make a node harder to tap', (tester) async {
      await _pump(tester);
      _pulse(tester).trigger(['a']);
      await tester.pump(const Duration(milliseconds: 100));
      final size = tester.getSize(
        find
            .ancestor(
              of: find.byKey(const Key('graph_node_a')),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(size.width, greaterThanOrEqualTo(44));
    });
  });

  group('asking from the graph', () {
    testWidgets('sends the question to chat, and the documents retrieval '
        'names pulse', (tester) async {
      final rig = await _pump(tester);
      await tester.enterText(find.byType(TextField).last, 'What is Zanzibar?');
      await tester.pump(); // the Ask button rebuilds on the next frame
      await tester.tap(find.text('Ask'));
      await _frames(tester, 2);

      expect(rig.stream.turns, hasLength(1));
      expect(rig.stream.turns.single.query, 'What is Zanzibar?');
      expect(_pulsing(tester), isEmpty, reason: 'pulsed before retrieval');

      rig.stream.turns.single.events.add(
        const ChatRetrieval(chunkIds: ['c1', 'c2'], documentIds: ['b', 'd']),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_pulsing(tester), {'b', 'd'});

      rig.stream.turns.single.events.add(const ChatToken('The answer.'));
      rig.stream.turns.single.events.add(const ChatDone());
      await rig.stream.turns.single.events.close();
      await _frames(tester);
      expect(find.byKey(const Key('graph_answer')), findsOneWidget);
      expect(
        find.byKey(const Key('graph_legend')),
        findsNothing,
        reason: 'the legend must not cover the answer',
      );
      expect(find.textContaining('The answer.'), findsWidgets);
    });

    testWidgets('the answer can be closed', (tester) async {
      final rig = await _pump(tester);
      await tester.enterText(find.byType(TextField).last, 'q');
      await tester.pump(); // the Ask button rebuilds on the next frame
      await tester.tap(find.text('Ask'));
      await _frames(tester, 2);
      rig.stream.turns.single.events.add(const ChatToken('hi'));
      rig.stream.turns.single.events.add(const ChatDone());
      await rig.stream.turns.single.events.close();
      await _frames(tester);

      await tester.tap(find.byKey(const Key('graph_answer_close')));
      await _frames(tester, 2);
      expect(find.byKey(const Key('graph_answer')), findsNothing);
      expect(find.byKey(const Key('graph_legend')), findsOneWidget);
    });

    testWidgets('a second question while one is running is not sent', (
      tester,
    ) async {
      final rig = await _pump(tester);
      final field = find.byType(TextField).last;
      await tester.enterText(field, 'first');
      await tester.pump(); // the Ask button rebuilds on the next frame
      await tester.tap(find.text('Ask'));
      await _frames(tester, 2);

      await tester.enterText(field, 'second');
      await tester.pump(); // the Ask button rebuilds on the next frame
      await tester.tap(find.text('Ask'));
      await _frames(tester, 2);

      expect(rig.stream.turns, hasLength(1));
      expect(
        tester.widget<TextField>(field).controller!.text,
        'second',
        reason: 'the unsent question was thrown away',
      );
      await rig.stream.turns.single.events.close();
    });
  });

  group('replaying a conversation', () {
    ChatSessionSummary session(String id, String preview) => ChatSessionSummary(
      id: id,
      createdAt: DateTime.utc(2026, 10, 3, 21),
      preview: preview,
    );

    ChatMessage answer(int id, List<String> docs) => ChatMessage(
      id: id,
      role: ChatRole.assistant,
      text: 'a',
      retrievalDone: true,
      retrievedDocumentIds: docs,
    );

    testWidgets('the history chip lists past conversations', (tester) async {
      final rig = await _pump(tester);
      rig.history.sessions = [
        session('s1', 'First question'),
        session('s2', 'Second question'),
      ];
      await tester.tap(find.byKey(const Key('graph_history')));
      await _frames(tester);

      expect(find.byKey(const Key('replay_sheet')), findsOneWidget);
      expect(find.text('First question'), findsOneWidget);
      expect(find.text('Second question'), findsOneWidget);
    });

    testWidgets('no conversations says so', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const Key('graph_history')));
      await _frames(tester);
      expect(find.byKey(const Key('replay_empty')), findsOneWidget);
    });

    testWidgets('picking one plays its pulses in the order they happened, one '
        'at a time, then stops', (tester) async {
      final rig = await _pump(tester);
      rig.history.sessions = [session('s1', 'Q')];
      rig.history.byId['s1'] = [
        ChatMessage.user(id: 0, text: 'q1'),
        answer(1, ['a', 'b']),
        ChatMessage.user(id: 2, text: 'q2'),
        answer(3, ['c']),
        ChatMessage.user(id: 4, text: 'q3'),
        answer(5, ['d', 'a']),
      ];
      await tester.tap(find.byKey(const Key('graph_history')));
      await _frames(tester);
      await tester.tap(find.byKey(const Key('replay_s1')));
      await _frames(tester, 2);

      expect(find.byKey(const Key('graph_replaying')), findsOneWidget);
      expect(_pulsing(tester), {'a', 'b'});

      await tester.pump(replayInterval);
      expect(_pulsing(tester), {'c'});

      await tester.pump(replayInterval);
      expect(_pulsing(tester), {'a', 'd'});

      await tester.pump(replayInterval + const Duration(milliseconds: 100));
      await tester.pump(pulseDuration);
      expect(find.byKey(const Key('graph_replaying')), findsNothing);
      expect(_pulsing(tester), isEmpty);
    });

    testWidgets('the same conversation shows what pulsed live: the documents '
        'retrieval named', (tester) async {
      // What a live turn pulsed...
      final rig = await _pump(tester);
      _pulse(tester).trigger(['b', 'd']);
      await tester.pump(const Duration(milliseconds: 100));
      final live = _pulsing(tester);
      await tester.pump(pulseDuration + const Duration(milliseconds: 100));

      // ...is what the stored copy of that retrieval replays.
      rig.history.sessions = [session('s1', 'Q')];
      rig.history.byId['s1'] = [
        ChatMessage.user(id: 0, text: 'q'),
        answer(1, ['d', 'b']), // stored order differs; it is a set
      ];
      await tester.tap(find.byKey(const Key('graph_history')));
      await _frames(tester);
      await tester.tap(find.byKey(const Key('replay_s1')));
      await _frames(tester, 2);

      expect(_pulsing(tester), live);

      // Let the replay run out so no timer outlives the test.
      await tester.pump(replayInterval + const Duration(milliseconds: 100));
      await tester.pump(pulseDuration);
    });

    testWidgets('Stop ends a replay; what is lit runs out', (tester) async {
      final rig = await _pump(tester);
      rig.history.sessions = [session('s1', 'Q')];
      rig.history.byId['s1'] = [
        ChatMessage.user(id: 0, text: 'q'),
        answer(1, ['a']),
        answer(2, ['b']),
      ];
      await tester.tap(find.byKey(const Key('graph_history')));
      await _frames(tester);
      await tester.tap(find.byKey(const Key('replay_s1')));
      await _frames(tester, 2);
      expect(_pulsing(tester), {'a'});

      await tester.tap(find.byKey(const Key('graph_replay_stop')));
      await tester.pump(replayInterval + const Duration(milliseconds: 100));
      await tester.pump(pulseDuration);

      expect(find.byKey(const Key('graph_replaying')), findsNothing);
      expect(_pulsing(tester), isEmpty, reason: "'b' pulsed after Stop");
    });

    testWidgets('a conversation that drew on nothing says so and replays '
        'nothing', (tester) async {
      final rig = await _pump(tester);
      rig.history.sessions = [session('s1', 'Q')];
      rig.history.byId['s1'] = [
        ChatMessage.user(id: 0, text: 'q'),
        answer(1, const []),
      ];
      await tester.tap(find.byKey(const Key('graph_history')));
      await _frames(tester);
      await tester.tap(find.byKey(const Key('replay_s1')));
      await _frames(tester, 3);

      expect(find.byKey(const Key('graph_replay_message')), findsOneWidget);
      expect(find.byKey(const Key('graph_replaying')), findsNothing);
      expect(_pulsing(tester), isEmpty);
    });

    testWidgets('a conversation that fails to load says so and replays '
        'nothing', (tester) async {
      final rig = await _pump(tester);
      rig.history.sessions = [session('s1', 'Q')];
      rig.history.messagesError = StateError('boom');
      await tester.tap(find.byKey(const Key('graph_history')));
      await _frames(tester);
      await tester.tap(find.byKey(const Key('replay_s1')));
      await _frames(tester, 3);

      expect(find.textContaining("Couldn't load"), findsOneWidget);
      expect(_pulsing(tester), isEmpty);
    });

    testWidgets('a live retrieval during a replay takes over', (tester) async {
      final rig = await _pump(tester);
      rig.history.sessions = [session('s1', 'Q')];
      rig.history.byId['s1'] = [
        ChatMessage.user(id: 0, text: 'q'),
        answer(1, ['a']),
        answer(2, ['b']),
      ];
      await tester.tap(find.byKey(const Key('graph_history')));
      await _frames(tester);
      await tester.tap(find.byKey(const Key('replay_s1')));
      await _frames(tester, 2);

      _pulse(tester).trigger(['d']);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_pulsing(tester), {'d'});
      await tester.pump(replayInterval);
      expect(_pulsing(tester), isNot(contains('b')));
      expect(find.byKey(const Key('graph_replaying')), findsNothing);
    });
  });
}
