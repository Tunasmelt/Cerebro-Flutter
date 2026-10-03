// Milestone 3.2 audit regressions, each reproduced before being fixed.
import 'dart:async';

import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/chat/data/chat_controller.dart';
import 'package:cerebro_mobile/features/chat/data/chat_sessions_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_client.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_event.dart';
import 'package:cerebro_mobile/features/chat/presentation/chat_screen.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Turn {
  late final StreamController<ChatStreamEvent> controller =
      StreamController<ChatStreamEvent>();
  void add(ChatStreamEvent e) => controller.add(e);
}

class _FakeStream implements ChatStreamApi {
  final List<_Turn> turns = [];
  @override
  Stream<ChatStreamEvent> stream({
    required String sessionId,
    required String query,
  }) {
    final turn = _Turn();
    turns.add(turn);
    return turn.controller.stream;
  }
}

class _FakeSessions implements ChatSessionsApi {
  @override
  Future<String> create() async => 'session-1';
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

/// Lists whatever [responses] says, one entry per call (the last repeats);
/// optionally holds the first call back until [gate] completes.
class _Documents implements DocumentsRepository {
  _Documents(this.responses, {this.gate, this.holdSecond});
  final List<List<DocumentSummary>> responses;
  final Completer<void>? gate;

  /// Holds the second call (the refresh) back until it completes.
  final Completer<void>? holdSecond;
  int calls = 0;

  @override
  Future<List<DocumentSummary>> listDocuments() async {
    final i = calls++;
    if (i == 0) await gate?.future;
    if (i == 1) await holdSecond?.future;
    return responses[i < responses.length ? i : responses.length - 1];
  }

  @override
  Future<DocumentDetail> getDocument(String id) => throw UnimplementedError();
}

class _Harness {
  final stream = _FakeStream();
  final opened = <String>[];
}

Future<_Harness> _pump(WidgetTester tester, _Documents documents) async {
  final h = _Harness();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        chatStreamApiProvider.overrideWithValue(h.stream),
        chatSessionsApiProvider.overrideWithValue(_FakeSessions()),
        documentsRepositoryProvider.overrideWithValue(documents),
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

Future<void> _settle(WidgetTester tester, [int ms = 80]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

Future<void> _ask(WidgetTester tester, String q) async {
  await tester.enterText(find.byKey(const Key('chat_input')), q);
  await tester.pump();
  await tester.tap(find.byKey(const Key('chat_send')));
  await _settle(tester);
}

void _answer(
  _Turn turn, {
  required String text,
  required Map<String, String> cited,
}) {
  turn.add(
    ChatRetrieval(
      chunkIds: cited.keys.toList(),
      documentIds: cited.values.toList(),
    ),
  );
  turn.add(ChatToken(text));
  cited.forEach(
    (chunk, doc) => turn.add(ChatCitation(chunkId: chunk, documentId: doc)),
  );
  turn.add(const ChatDone());
}

void main() {
  testWidgets(
    'a document that exists but is newer than the loaded list is NOT shown '
    'as "no longer available" — the list is refreshed and the chip works',
    (tester) async {
      // The list loaded earlier holds only d1. d2 was uploaded from another
      // device since (the next fetch returns it).
      final documents = _Documents([
        [_doc('d1', 'old.txt')],
        [_doc('d1', 'old.txt'), _doc('d2', 'from-the-web.txt')],
      ]);
      final h = await _pump(tester, documents);
      await _ask(tester, 'q');

      _answer(
        h.stream.turns.single,
        text: 'It is in the new file.[[chunk:c2]]',
        cited: {'c2': 'd2'},
      );
      await _settle(tester);
      await _settle(tester); // let the refresh land

      await tester.tap(find.byKey(const Key('citation_chip_1')));
      await tester.pump();
      expect(h.opened, [
        'd2',
      ], reason: 'the chip was muted/inert for a document that exists');
      expect(find.text('from-the-web.txt'), findsOneWidget);
    },
  );

  testWidgets(
    'while that refresh is still in flight the chip is usable, not flashed '
    'muted ("unknown" is not "missing")',
    (tester) async {
      final hold = Completer<void>();
      final documents = _Documents([
        [_doc('d1', 'old.txt')],
        [_doc('d1', 'old.txt'), _doc('d2', 'from-the-web.txt')],
      ], holdSecond: hold);
      final h = await _pump(tester, documents);
      await _ask(tester, 'q');

      _answer(
        h.stream.turns.single,
        text: 'It is in the new file.[[chunk:c2]]',
        cited: {'c2': 'd2'},
      );
      await _settle(tester);
      expect(documents.calls, 2, reason: 'the refresh has started and is held');

      await tester.tap(find.byKey(const Key('citation_chip_1')));
      await tester.pump();
      expect(h.opened, ['d2']);

      hold.complete();
      await _settle(tester);
    },
  );

  testWidgets('a document that really is gone stays muted after the refresh', (
    tester,
  ) async {
    final documents = _Documents([
      [_doc('d1', 'only.txt')],
    ]);
    final h = await _pump(tester, documents);
    await _ask(tester, 'q');

    _answer(
      h.stream.turns.single,
      text: 'From a deleted file.[[chunk:c9]]',
      cited: {'c9': 'gone'},
    );
    await _settle(tester);
    await _settle(tester);

    await tester.tap(find.byKey(const Key('citation_chip_1')));
    await tester.pump();
    expect(h.opened, isEmpty);
    expect(
      documents.calls,
      greaterThan(1),
      reason: 'it checked before giving up',
    );
  });

  testWidgets('the list is not re-fetched when every cited document is known', (
    tester,
  ) async {
    final documents = _Documents([
      [_doc('d1', 'a.txt')],
    ]);
    final h = await _pump(tester, documents);
    await _ask(tester, 'q');
    final before = documents.calls;

    _answer(
      h.stream.turns.single,
      text: 'Known.[[chunk:c1]]',
      cited: {'c1': 'd1'},
    );
    await _settle(tester);
    await _settle(tester);

    expect(documents.calls, before, reason: 'no needless refresh');
  });

  testWidgets('while the document list is still loading, chips are usable '
      '(unknown is not the same as missing)', (tester) async {
    final gate = Completer<void>();
    final documents = _Documents([
      [_doc('d1', 'a.txt')],
    ], gate: gate);
    final h = await _pump(tester, documents);
    await _ask(tester, 'q');

    _answer(
      h.stream.turns.single,
      text: 'Answer.[[chunk:c1]]',
      cited: {'c1': 'd1'},
    );
    await _settle(tester);

    await tester.tap(find.byKey(const Key('citation_chip_1')));
    await tester.pump();
    expect(h.opened, ['d1']);

    gate.complete();
    await _settle(tester);
  });

  testWidgets('the same source cited twice draws two chips without error', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      _Documents([
        [_doc('d1', 'a.txt')],
      ]),
    );
    await _ask(tester, 'q');
    _answer(
      h.stream.turns.single,
      text: 'First.[[chunk:c1]] Second.[[chunk:c1]]',
      cited: {'c1': 'd1'},
    );
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('citation_chip_1')), findsNWidgets(2));
    expect(find.byKey(const Key('source_chip_d1')), findsOneWidget);
  });
}
