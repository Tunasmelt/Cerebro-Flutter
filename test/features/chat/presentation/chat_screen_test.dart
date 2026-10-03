// The chat screen against a controllable fake stream. The progress indicators
// animate forever, so these tests pump bounded durations, never settle.
import 'dart:async';

import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/chat/data/chat_controller.dart';
import 'package:cerebro_mobile/features/chat/data/chat_sessions_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_client.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_event.dart';
import 'package:cerebro_mobile/features/chat/presentation/chat_screen.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../documents/fake_documents_repository.dart';

class _Turn {
  _Turn(this.query);
  final String query;
  bool cancelled = false;
  late final StreamController<ChatStreamEvent> controller =
      StreamController<ChatStreamEvent>(onCancel: () => cancelled = true);
  void add(ChatStreamEvent e) => controller.add(e);
}

class _FakeStream implements ChatStreamApi {
  final List<_Turn> turns = [];
  @override
  Stream<ChatStreamEvent> stream({
    required String sessionId,
    required String query,
  }) {
    final turn = _Turn(query);
    turns.add(turn);
    return turn.controller.stream;
  }
}

class _FakeSessions implements ChatSessionsApi {
  int created = 0;
  @override
  Future<String> create() async => 'session-${++created}';
}

DocumentSummary _doc(String id, String title) => DocumentSummary(
  id: id,
  title: title,
  mime: 'text/plain',
  sizeBytes: 10,
  originalSizeBytes: 10,
  status: DocumentStatus.ready,
  createdAt: DateTime.utc(2026),
);

class _Harness {
  final stream = _FakeStream();
  final sessions = _FakeSessions();
  final opened = <String>[];
}

Future<_Harness> _pump(
  WidgetTester tester, {
  List<DocumentSummary>? documents,
}) async {
  final h = _Harness();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        chatStreamApiProvider.overrideWithValue(h.stream),
        chatSessionsApiProvider.overrideWithValue(h.sessions),
        documentsRepositoryProvider.overrideWithValue(
          FakeDocumentsRepository(
            documents: documents ?? [_doc('d1', 'notes.txt')],
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: ChatScreen(openDocument: (_, id) => h.opened.add(id)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return h;
}

Future<void> _pumpFor(WidgetTester tester, [int ms = 60]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

Future<void> _ask(WidgetTester tester, String question) async {
  await tester.enterText(find.byKey(const Key('chat_input')), question);
  await tester.pump();
  await tester.tap(find.byKey(const Key('chat_send')));
  await _pumpFor(tester);
}

/// All text currently on screen.
String _screenText(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(find.byType(Text)))
    t.data ?? t.textSpan?.toPlainText(includePlaceholders: false) ?? '',
  for (final t in tester.widgetList<SelectableText>(
    find.byType(SelectableText),
  ))
    t.data ?? '',
].join('\n');

const _retrieval = ChatRetrieval(chunkIds: ['c1', 'c2'], documentIds: ['d1']);

void main() {
  testWidgets('starts empty, and Send is disabled until there is a question', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byKey(const Key('chat_empty')), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('chat_send'))).onPressed,
      isNull,
    );

    await tester.enterText(find.byKey(const Key('chat_input')), '   ');
    await tester.pump();
    expect(
      tester.widget<IconButton>(find.byKey(const Key('chat_send'))).onPressed,
      isNull,
      reason: 'whitespace is not a question',
    );

    await tester.enterText(find.byKey(const Key('chat_input')), 'hello');
    await tester.pump();
    expect(
      tester.widget<IconButton>(find.byKey(const Key('chat_send'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('asking shows the question, clears the box, and walks through '
      'searching → writing → the answer', (tester) async {
    final h = await _pump(tester);

    await _ask(tester, 'What is Cerebro?');
    expect(find.text('What is Cerebro?'), findsOneWidget);
    expect(find.byKey(const Key('chat_empty')), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('chat_input')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.text('Searching your documents…'), findsOneWidget);
    expect(find.byKey(const Key('chat_stop')), findsOneWidget);

    final turn = h.stream.turns.single;
    turn.add(_retrieval);
    await _pumpFor(tester);
    expect(find.text('Writing the answer…'), findsOneWidget);

    turn.add(const ChatToken('Cerebro is a memory graph.'));
    await _pumpFor(tester);
    expect(find.text('Writing the answer…'), findsNothing);
    expect(find.text('Cerebro is a memory graph.'), findsOneWidget);

    turn.add(const ChatDone());
    await _pumpFor(tester);
    expect(find.byKey(const Key('chat_send')), findsOneWidget);
    expect(find.byKey(const Key('chat_stop')), findsNothing);
  });

  testWidgets('the answer appears progressively, token by token', (
    tester,
  ) async {
    final h = await _pump(tester);
    await _ask(tester, 'q');
    final turn = h.stream.turns.single;
    turn.add(_retrieval);

    final seen = <String>[];
    for (final piece in ['Memory ', 'graphs ', 'link ', 'ideas.']) {
      turn.add(ChatToken(piece));
      await _pumpFor(tester);
      seen.add(_screenText(tester).contains('Memory') ? 'has-text' : 'none');
    }
    expect(find.text('Memory graphs link ideas.'), findsOneWidget);
    expect(seen, everyElement('has-text'));
  });

  testWidgets('the rest of the answer is not on screen before it has arrived', (
    tester,
  ) async {
    final h = await _pump(tester);
    await _ask(tester, 'again');
    h.stream.turns.single.add(_retrieval);
    h.stream.turns.single.add(const ChatToken('Half '));
    await _pumpFor(tester);

    expect(find.textContaining('ideas'), findsNothing);
    expect(find.text('Half '), findsOneWidget);
  });

  group('citations', () {
    testWidgets('raw [[chunk:…]] syntax is never on screen, even when a marker '
        'arrives split across tokens', (tester) async {
      final h = await _pump(tester);
      await _ask(tester, 'q');
      final turn = h.stream.turns.single;
      turn.add(_retrieval);

      for (final piece in [
        'It is a graph.',
        '[',
        '[ch',
        'unk:c',
        '1]]',
        ' It stores notes.',
      ]) {
        turn.add(ChatToken(piece));
        await _pumpFor(tester);
        final shown = _screenText(tester);
        expect(shown, isNot(contains('[[')), reason: 'after "$piece"');
        expect(shown, isNot(contains('chunk:')), reason: 'after "$piece"');
      }
      turn.add(const ChatCitation(chunkId: 'c1', documentId: 'd1'));
      turn.add(const ChatDone());
      await _pumpFor(tester);

      final shown = _screenText(tester);
      expect(shown, isNot(contains('[[')));
      expect(shown, isNot(contains('chunk:')));
      expect(shown, contains('It is a graph.'));
      expect(shown, contains('It stores notes.'));
    });

    testWidgets('a cited answer shows a numbered chip and the source document '
        'by title; tapping either opens that document', (tester) async {
      final h = await _pump(tester);
      await _ask(tester, 'q');
      final turn = h.stream.turns.single;
      turn.add(_retrieval);
      turn.add(const ChatToken('Cerebro is a graph.[[chunk:c1]]'));
      turn.add(const ChatCitation(chunkId: 'c1', documentId: 'd1'));
      turn.add(const ChatDone());
      await _pumpFor(tester);

      expect(find.byKey(const Key('citation_chip_1')), findsOneWidget);
      expect(find.byKey(const Key('source_chip_d1')), findsOneWidget);
      expect(find.text('notes.txt'), findsOneWidget);

      await tester.tap(find.byKey(const Key('citation_chip_1')));
      await tester.pump();
      expect(h.opened, ['d1']);

      await tester.tap(find.byKey(const Key('source_chip_d1')));
      await tester.pump();
      expect(h.opened, ['d1', 'd1']);
    });

    testWidgets('an inline chip is a small footnote, not a bar across the line '
        '(regression: a Container with `alignment` filled the whole width)', (
      tester,
    ) async {
      final h = await _pump(tester);
      await _ask(tester, 'q');
      final turn = h.stream.turns.single;
      turn.add(_retrieval);
      turn.add(const ChatToken('Cerebro is a graph.[[chunk:c1]] More text.'));
      turn.add(const ChatCitation(chunkId: 'c1', documentId: 'd1'));
      turn.add(const ChatDone());
      await _pumpFor(tester);

      final chip = tester.getSize(find.byKey(const Key('citation_chip_1')));
      expect(chip.width, lessThan(60), reason: 'chip is ${chip.width}px wide');
      expect(chip.height, lessThan(40));
      // The full stop after the chip stays on the same line as the text.
      final answer = tester.getRect(find.byKey(const Key('chat_answer_1')));
      expect(
        tester.getRect(find.byKey(const Key('citation_chip_1'))).width,
        lessThan(answer.width / 4),
      );
    });

    testWidgets('a marker the server did not back draws no chip and no raw '
        'text', (tester) async {
      final h = await _pump(tester);
      await _ask(tester, 'q');
      final turn = h.stream.turns.single;
      turn.add(_retrieval); // retrieved: c1, c2
      turn.add(
        const ChatToken('Real.[[chunk:c1]] Invented.[[chunk:ghost]] End.'),
      );
      turn.add(const ChatCitation(chunkId: 'c1', documentId: 'd1'));
      turn.add(const ChatDone());
      await _pumpFor(tester);

      expect(find.byKey(const Key('citation_chip_1')), findsOneWidget);
      expect(find.byKey(const Key('citation_chip_2')), findsNothing);
      expect(_screenText(tester), isNot(contains('ghost')));
      expect(_screenText(tester), isNot(contains('[[')));
    });

    testWidgets('a citation for a chunk outside the retrieval set is not a '
        'chip even if a citation event names it', (tester) async {
      final h = await _pump(tester);
      await _ask(tester, 'q');
      final turn = h.stream.turns.single;
      turn.add(const ChatRetrieval(chunkIds: ['c1'], documentIds: ['d1']));
      turn.add(const ChatToken('A.[[chunk:other]]'));
      turn.add(const ChatCitation(chunkId: 'other', documentId: 'd1'));
      turn.add(const ChatDone());
      await _pumpFor(tester);

      expect(find.byKey(const Key('citation_chip_1')), findsNothing);
      expect(find.byKey(const Key('source_chip_d1')), findsNothing);
    });

    testWidgets('a source whose document no longer exists is muted and inert, '
        'not a link that goes nowhere', (tester) async {
      final h = await _pump(tester, documents: [_doc('d1', 'notes.txt')]);
      await _ask(tester, 'q');
      final turn = h.stream.turns.single;
      turn.add(const ChatRetrieval(chunkIds: ['c9'], documentIds: ['deleted']));
      turn.add(const ChatToken('From a gone file.[[chunk:c9]]'));
      turn.add(const ChatCitation(chunkId: 'c9', documentId: 'deleted'));
      turn.add(const ChatDone());
      await _pumpFor(tester);

      await tester.tap(find.byKey(const Key('citation_chip_1')));
      await tester.tap(find.byKey(const Key('source_chip_deleted')));
      await tester.pump();

      expect(h.opened, isEmpty);
    });
  });

  group('no matching documents', () {
    testWidgets('is shown distinctly when retrieval finds nothing, and not '
        'for a normal cited answer', (tester) async {
      final h = await _pump(tester);
      await _ask(tester, 'something unrelated');
      final turn = h.stream.turns.single;
      turn.add(const ChatRetrieval(chunkIds: [], documentIds: []));
      turn.add(const ChatToken('I could not find that in your documents.'));
      turn.add(const ChatDone());
      await _pumpFor(tester);

      expect(find.text('No matching documents'), findsOneWidget);
      expect(find.byKey(const Key('chat_no_matches_1')), findsOneWidget);
      expect(find.byKey(const Key('source_chip_d1')), findsNothing);

      // A grounded answer in the same conversation has no such notice.
      await _ask(tester, 'what is in notes?');
      final second = h.stream.turns[1];
      second.add(_retrieval);
      second.add(const ChatToken('Notes say hi.[[chunk:c1]]'));
      second.add(const ChatCitation(chunkId: 'c1', documentId: 'd1'));
      second.add(const ChatDone());
      await _pumpFor(tester);

      expect(
        find.text('No matching documents'),
        findsOneWidget,
        reason: 'only the first answer, not the grounded one',
      );
      expect(find.byKey(const Key('chat_no_matches_3')), findsNothing);
    });

    testWidgets('is not claimed while retrieval is still running', (
      tester,
    ) async {
      final h = await _pump(tester);
      await _ask(tester, 'q');
      h.stream.turns.single.add(const ChatHeartbeat());
      await _pumpFor(tester);

      expect(find.text('No matching documents'), findsNothing);
      expect(find.text('Searching your documents…'), findsOneWidget);
    });
  });

  group('when something goes wrong', () {
    testWidgets('a failed answer keeps its partial text, explains in plain '
        'words, and "Try again" re-asks', (tester) async {
      final h = await _pump(tester);
      await _ask(tester, 'Why?');
      final turn = h.stream.turns.single;
      turn.add(_retrieval);
      turn.add(const ChatToken('It is because'));
      turn.add(
        const ChatError(code: 'chat_turn_failed', rawMessage: 'ReadTimeout'),
      );
      await _pumpFor(tester);

      expect(find.text('It is because'), findsOneWidget);
      expect(find.textContaining('incomplete'), findsOneWidget);
      expect(_screenText(tester), isNot(contains('ReadTimeout')));
      expect(find.byKey(const Key('chat_retry')), findsOneWidget);
      expect(find.byKey(const Key('chat_send')), findsOneWidget);

      await tester.tap(find.byKey(const Key('chat_retry')));
      await _pumpFor(tester);

      expect(h.stream.turns, hasLength(2));
      expect(h.stream.turns[1].query, 'Why?');
      expect(find.text('Why?'), findsOneWidget, reason: 'one question bubble');
      expect(find.byKey(const Key('chat_retry')), findsNothing);
    });

    testWidgets('a connection failure says so', (tester) async {
      final h = await _pump(tester);
      await _ask(tester, 'q');
      h.stream.turns.single.controller.addError(
        const NetworkUnreachableException(),
      );
      await _pumpFor(tester);

      expect(find.textContaining("Can't reach Cerebro"), findsOneWidget);
      expect(find.byKey(const Key('chat_retry')), findsOneWidget);
    });
  });

  group('Stop', () {
    testWidgets('keeps the partial answer, marks it stopped, and the box '
        'works again', (tester) async {
      final h = await _pump(tester);
      await _ask(tester, 'q');
      final turn = h.stream.turns.single;
      turn.add(_retrieval);
      turn.add(const ChatToken('Half an ans'));
      await _pumpFor(tester);

      await tester.tap(find.byKey(const Key('chat_stop')));
      await _pumpFor(tester);

      expect(find.text('Half an ans'), findsOneWidget);
      expect(find.text('Stopped'), findsOneWidget);
      expect(turn.cancelled, isTrue);
      expect(find.byKey(const Key('chat_send')), findsOneWidget);

      await _ask(tester, 'next');
      expect(h.stream.turns, hasLength(2));
    });
  });

  group('New chat', () {
    testWidgets('clears the conversation and the next question starts a new '
        'session', (tester) async {
      final h = await _pump(tester);
      expect(find.byKey(const Key('chat_new')), findsNothing);

      await _ask(tester, 'first');
      h.stream.turns.single.add(const ChatDone());
      await _pumpFor(tester);
      expect(find.byKey(const Key('chat_new')), findsOneWidget);

      await tester.tap(find.byKey(const Key('chat_new')));
      await _pumpFor(tester);
      expect(find.text('first'), findsNothing);
      expect(find.byKey(const Key('chat_empty')), findsOneWidget);

      await _ask(tester, 'second');
      expect(h.sessions.created, 2);
    });
  });

  group('scrolling', () {
    Future<_Harness> longConversation(WidgetTester tester) async {
      final h = await _pump(tester);
      for (var i = 0; i < 8; i++) {
        await _ask(tester, 'Question number $i');
        final turn = h.stream.turns.last;
        turn.add(_retrieval);
        turn.add(ChatToken('Answer $i. ${'More words. ' * 40}'));
        turn.add(const ChatDone());
        await _pumpFor(tester);
      }
      return h;
    }

    ScrollPosition position(WidgetTester tester) => tester
        .widget<ListView>(find.byKey(const Key('chat_messages')))
        .controller!
        .position;

    testWidgets('a new question scrolls to the bottom', (tester) async {
      await longConversation(tester);
      final p = position(tester);
      expect(p.maxScrollExtent, greaterThan(0));
      expect(p.pixels, closeTo(p.maxScrollExtent, 2));
    });

    testWidgets('a streaming answer follows the bottom while you are there '
        'but never drags you back down once you have scrolled up', (
      tester,
    ) async {
      final h = await longConversation(tester);
      await _ask(tester, 'One more');
      final turn = h.stream.turns.last;
      turn.add(_retrieval);

      // At the bottom: new text keeps it in view.
      turn.add(ChatToken('Following along. ${'Lots of words here. ' * 40}'));
      await _pumpFor(tester);
      var p = position(tester);
      expect(p.pixels, closeTo(p.maxScrollExtent, 2));

      // Scroll up to re-read something.
      await tester.drag(
        find.byKey(const Key('chat_messages')),
        const Offset(0, 600),
      );
      await _pumpFor(tester);
      final scrolledTo = position(tester).pixels;
      expect(scrolledTo, lessThan(position(tester).maxScrollExtent - 100));

      turn.add(ChatToken('Even more text arrives. ${'Still going. ' * 40}'));
      await _pumpFor(tester);

      expect(
        position(tester).pixels,
        closeTo(scrolledTo, 2),
        reason: 'the user is reading; the stream must not move them',
      );
    });
  });
}
