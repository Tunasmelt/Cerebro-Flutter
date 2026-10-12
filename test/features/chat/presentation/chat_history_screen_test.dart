// The conversation list, and the Chat screen's reopen / export affordances.
import 'dart:async';

import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/chat/data/chat_controller.dart';
import 'package:cerebro_mobile/features/chat/data/chat_export_service.dart';
import 'package:cerebro_mobile/features/chat/data/chat_history_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_message.dart';
import 'package:cerebro_mobile/features/chat/data/chat_sessions_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_client.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_event.dart';
import 'package:cerebro_mobile/features/chat/data/conversation_exporter.dart';
import 'package:cerebro_mobile/features/chat/presentation/chat_history_screen.dart';
import 'package:cerebro_mobile/features/chat/presentation/chat_screen.dart';
import 'package:cerebro_mobile/features/chat/presentation/conversation_date.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../documents/fake_documents_repository.dart';

class _FakeHistory implements ChatHistoryApi {
  List<ChatSessionSummary> sessions = [];
  final Map<String, List<ChatMessage>> byId = {};
  Object? listError;
  Object? messagesError;
  Object? deleteError;
  Completer<void>? messagesGate;
  final deleted = <String>[];
  int listCalls = 0;

  @override
  Future<List<ChatSessionSummary>> list() async {
    listCalls++;
    final e = listError;
    if (e != null) throw e;
    return List.of(sessions);
  }

  @override
  Future<ChatHistory> messages(String id) async {
    await messagesGate?.future;
    final e = messagesError;
    if (e != null) throw e;
    return ChatHistory(messages: byId[id] ?? const []);
  }

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    final e = deleteError;
    if (e != null) throw e;
    sessions.removeWhere((s) => s.id == id);
  }
}

class _NoStream implements ChatStreamApi {
  @override
  Stream<ChatStreamEvent> stream({
    required String sessionId,
    required String query,
  }) => const Stream.empty();
}

class _NoSessions implements ChatSessionsApi {
  @override
  Future<String> create() async => 'new';
}

class _FakeExporter implements ConversationExporter {
  final exported = <({String fileName, String markdown})>[];
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

class _H {
  final history = _FakeHistory();
  final exporter = _FakeExporter();
}

Future<_H> _pump(
  WidgetTester tester, {
  Widget home = const ChatHistoryScreen(),
  void Function(_H h)? configure,
  Override? ownerOverride,
}) async {
  final h = _H();
  configure?.call(h);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ownerOverride ?? currentUserIdProvider.overrideWithValue('user-1'),
        chatHistoryApiProvider.overrideWithValue(h.history),
        chatStreamApiProvider.overrideWithValue(_NoStream()),
        chatSessionsApiProvider.overrideWithValue(_NoSessions()),
        conversationExporterProvider.overrideWithValue(h.exporter),
        documentsRepositoryProvider.overrideWithValue(
          FakeDocumentsRepository(documents: const []),
        ),
      ],
      child: MaterialApp(theme: AppTheme.dark, home: home),
    ),
  );
  await _settle(tester);
  return h;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

String _text(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(find.byType(Text)))
    t.data ?? t.textSpan?.toPlainText(includePlaceholders: false) ?? '',
  for (final t in tester.widgetList<SelectableText>(
    find.byType(SelectableText),
  ))
    t.data ?? '',
].join('\n');

Future<void> _menu(WidgetTester tester, String id, String item) async {
  await tester.tap(find.byKey(Key('chat_session_menu_$id')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byKey(Key(item)));
  await _settle(tester);
}

void _open(WidgetTester tester, String id) {
  _container(
    tester,
  ).read(chatControllerProvider.notifier).openSession(_session(id));
}

void main() {
  testWidgets('swipe Undo restores history without a server deletion', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      home: const ChatHistoryScreen(),
      configure: (h) =>
          h.history.sessions = [_session('swipe', preview: 'Swipe me')],
    );
    await tester.drag(
      find.byKey(const Key('chat_swipe_swipe')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(h.history.deleted, isEmpty);
    expect(find.text('Swipe me'), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(h.history.deleted, isEmpty);
    expect(find.text('Swipe me'), findsOneWidget);
  });

  testWidgets(
    'swipe deletes only after the Undo window and failures restore the row',
    (tester) async {
      final h = await _pump(
        tester,
        home: const ChatHistoryScreen(),
        configure: (h) {
          h.history.sessions = [_session('swipe', preview: 'Swipe me')];
          h.history.deleteError = const NetworkUnreachableException();
        },
      );
      await tester.drag(
        find.byKey(const Key('chat_swipe_swipe')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      expect(h.history.deleted, isEmpty);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(h.history.deleted, ['swipe']);
      expect(find.text('Swipe me'), findsOneWidget);
    },
  );

  testWidgets('account change cancels a pending swipe deletion', (
    tester,
  ) async {
    final owner = StateProvider<String?>((ref) => 'user-1');
    final h = await _pump(
      tester,
      home: const ChatHistoryScreen(),
      ownerOverride: currentUserIdProvider.overrideWith(
        (ref) => ref.watch(owner),
      ),
      configure: (h) =>
          h.history.sessions = [_session('swipe', preview: 'Swipe me')],
    );
    await tester.drag(
      find.byKey(const Key('chat_swipe_swipe')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatHistoryScreen)),
    );
    container.read(owner.notifier).state = 'second';
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(h.history.deleted, isEmpty);
  });

  group('formatConversationWhen', () {
    final now = DateTime(2026, 10, 3, 12);
    test('this year omits the year, 12-hour clock', () {
      expect(
        formatConversationWhen(DateTime(2026, 10, 3, 21, 5), now: now),
        'Oct 3, 9:05 PM',
      );
      expect(
        formatConversationWhen(DateTime(2026, 1, 9, 0, 7), now: now),
        'Jan 9, 12:07 AM',
      );
      expect(
        formatConversationWhen(DateTime(2026, 5, 1, 12, 0), now: now),
        'May 1, 12:00 PM',
      );
    });
    test('another year shows it', () {
      expect(
        formatConversationWhen(DateTime(2025, 12, 31, 23, 59), now: now),
        'Dec 31, 2025, 11:59 PM',
      );
    });
  });

  group('history screen', () {
    testWidgets('lists conversations with preview; no question reads as such', (
      tester,
    ) async {
      await _pump(
        tester,
        configure: (h) => h.history.sessions = [
          _session('s1', preview: 'Who invented the Zanzibar Protocol?'),
          _session('s2'),
        ],
      );
      final text = _text(tester);
      expect(text, contains('Who invented the Zanzibar Protocol?'));
      expect(text, contains('No question asked'));
      expect(find.byKey(const Key('chat_session_s1')), findsOneWidget);
      expect(find.byKey(const Key('chat_session_s2')), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      await _pump(tester);
      expect(find.byKey(const Key('chat_history_empty')), findsOneWidget);
    });

    testWidgets('a failed load shows the error with a working retry', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        configure: (h) =>
            h.history.listError = const NetworkUnreachableException(),
      );
      expect(find.byKey(const Key('chat_history_error')), findsOneWidget);

      h.history
        ..listError = null
        ..sessions = [_session('s1', preview: 'Back online')];
      await tester.tap(find.byKey(const Key('error_view_retry')));
      await _settle(tester);
      expect(find.text('Back online'), findsOneWidget);
    });

    testWidgets('tapping a row opens that conversation in Chat', (
      tester,
    ) async {
      await _pump(
        tester,
        configure: (h) {
          h.history.sessions = [_session('s1', preview: 'Who invented it?')];
          h.history.byId['s1'] = _conversation();
        },
      );
      await tester.tap(find.byKey(const Key('chat_session_s1')));
      await _settle(tester);

      final chat = _container(tester).read(chatControllerProvider);
      expect(chat.sessionId, 's1');
      expect(chat.messages.map((m) => m.text), [
        'Who invented it?',
        'Dr. Quartermain.[[chunk:c1]]',
      ]);
    });

    testWidgets('delete asks first; cancel keeps it, confirm removes it', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        configure: (h) => h.history.sessions = [_session('s1', preview: 'Q')],
      );

      await _menu(tester, 's1', 'chat_session_delete');
      expect(find.text('Delete this conversation?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat_delete_cancel')));
      await _settle(tester);
      expect(h.history.deleted, isEmpty);
      expect(find.byKey(const Key('chat_session_s1')), findsOneWidget);

      await _menu(tester, 's1', 'chat_session_delete');
      await tester.tap(find.byKey(const Key('chat_delete_confirm')));
      await _settle(tester);
      expect(h.history.deleted, ['s1']);
      expect(find.byKey(const Key('chat_session_s1')), findsNothing);
    });

    testWidgets('a failed delete leaves the row and says why', (tester) async {
      await _pump(
        tester,
        configure: (h) {
          h.history.sessions = [_session('s1', preview: 'Q')];
          h.history.deleteError = const NetworkUnreachableException();
        },
      );
      await _menu(tester, 's1', 'chat_session_delete');
      await tester.tap(find.byKey(const Key('chat_delete_confirm')));
      await _settle(tester);

      expect(find.byKey(const Key('chat_session_s1')), findsOneWidget);
      expect(find.byKey(const Key('chat_history_message')), findsOneWidget);
    });

    testWidgets('export hands the Markdown to the exporter', (tester) async {
      final h = await _pump(
        tester,
        configure: (h) {
          h.history.sessions = [_session('s1', preview: 'Q')];
          h.history.byId['s1'] = _conversation();
        },
      );
      await _menu(tester, 's1', 'chat_session_export');

      expect(h.exporter.exported, hasLength(1));
      expect(h.exporter.exported.single.fileName, 'cerebro-chat-s1.md');
      final md = h.exporter.exported.single.markdown;
      expect(md, contains('## You'));
      expect(md, contains('Who invented it?'));
      expect(md, contains('zanzibar.txt'));
      expect(md, isNot(contains('[[chunk')));
    });

    testWidgets('a failed export says so, and the row is usable again', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        configure: (h) {
          h.history.sessions = [_session('s1', preview: 'Q')];
          h.history.byId['s1'] = _conversation();
          h.exporter.error = StateError('disk full');
        },
      );
      await _menu(tester, 's1', 'chat_session_export');

      expect(find.byKey(const Key('chat_history_message')), findsOneWidget);
      expect(_text(tester), contains("Couldn't export this conversation."));
      expect(find.byKey(const Key('chat_session_menu_s1')), findsOneWidget);
      expect(h.exporter.exported, isEmpty);
    });
  });

  group('chat screen', () {
    testWidgets('a reopened conversation shows its messages and the '
        "server's source title", (tester) async {
      await _pump(
        tester,
        home: const ChatScreen(),
        configure: (h) => h.history.byId['s1'] = _conversation(),
      );
      expect(find.byKey(const Key('chat_export')), findsNothing);
      expect(find.byKey(const Key('chat_new')), findsNothing);

      _open(tester, 's1');
      await _settle(tester);

      final text = _text(tester);
      expect(text, contains('Who invented it?'));
      expect(text, contains('Dr. Quartermain.'));
      expect(text, isNot(contains('[[chunk')));
      expect(text, contains('zanzibar.txt'));
      expect(find.byKey(const Key('chat_export')), findsOneWidget);
      expect(find.byKey(const Key('chat_new')), findsOneWidget);
    });

    testWidgets('while loading: spinner shown, composer disabled', (
      tester,
    ) async {
      final gate = Completer<void>();
      await _pump(
        tester,
        home: const ChatScreen(),
        configure: (h) {
          h.history.byId['s1'] = _conversation();
          h.history.messagesGate = gate;
        },
      );
      _open(tester, 's1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('chat_loading')), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(const Key('chat_input'))).enabled,
        isFalse,
      );
      expect(find.byKey(const Key('chat_export')), findsNothing);

      gate.complete();
      await _settle(tester);
      expect(find.byKey(const Key('chat_loading')), findsNothing);
      expect(
        tester.widget<TextField>(find.byKey(const Key('chat_input'))).enabled,
        isTrue,
      );
    });

    testWidgets('a draft typed before reopening cannot be sent into a '
        'conversation that is still loading', (tester) async {
      final gate = Completer<void>();
      await _pump(
        tester,
        home: const ChatScreen(),
        configure: (h) {
          h.history.byId['s1'] = _conversation();
          h.history.messagesGate = gate;
        },
      );
      await tester.enterText(find.byKey(const Key('chat_input')), 'a draft');
      await tester.pump();
      expect(
        tester.widget<IconButton>(find.byKey(const Key('chat_send'))).onPressed,
        isNotNull,
      );

      _open(tester, 's1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        tester.widget<IconButton>(find.byKey(const Key('chat_send'))).onPressed,
        isNull,
        reason: 'Send must be off while the conversation loads',
      );
      gate.complete();
      await _settle(tester);
    });

    testWidgets('a load failure shows an error, keeps the composer off, and '
        'retry recovers', (tester) async {
      final h = await _pump(
        tester,
        home: const ChatScreen(),
        configure: (h) {
          h.history.byId['s1'] = _conversation();
          h.history.messagesError = const NetworkUnreachableException();
        },
      );
      _open(tester, 's1');
      await _settle(tester);

      expect(find.byKey(const Key('chat_load_error')), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(const Key('chat_input'))).enabled,
        isFalse,
      );

      h.history.messagesError = null;
      await tester.tap(find.byKey(const Key('error_view_retry')));
      await _settle(tester);
      expect(find.byKey(const Key('chat_load_error')), findsNothing);
      expect(_text(tester), contains('Dr. Quartermain.'));
    });

    testWidgets('a conversation that no longer exists offers New chat, not '
        'retry', (tester) async {
      await _pump(
        tester,
        home: const ChatScreen(),
        configure: (h) => h.history.messagesError =
            const RequestRejectedException('x', code: 'not_found'),
      );
      _open(tester, 'gone');
      await _settle(tester);

      expect(find.byKey(const Key('chat_load_error')), findsOneWidget);
      expect(find.byKey(const Key('error_view_retry')), findsNothing);
      await tester.tap(find.byKey(const Key('chat_new')));
      await _settle(tester);
      expect(find.byKey(const Key('chat_empty')), findsOneWidget);
    });

    testWidgets('Export on the open conversation shares it', (tester) async {
      final h = await _pump(
        tester,
        home: const ChatScreen(),
        configure: (h) => h.history.byId['s1'] = _conversation(),
      );
      _open(tester, 's1');
      await _settle(tester);

      await tester.tap(find.byKey(const Key('chat_export')));
      await _settle(tester);
      expect(h.exporter.exported, hasLength(1));
      expect(h.exporter.exported.single.markdown, contains('Dr. Quartermain.'));
    });
  });
}
