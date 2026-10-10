import 'package:cerebro_mobile/core/network/connection_status_notifier.dart';
import 'package:cerebro_mobile/features/auth/data/auth_notifier.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/graph/data/graph_api.dart';
import 'package:cerebro_mobile/features/graph/data/graph_models.dart';
import 'package:cerebro_mobile/features/graph/presentation/graph_screen.dart';
import 'package:cerebro_mobile/features/chat/data/chat_history_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_controller.dart';
import 'package:cerebro_mobile/features/chat/data/chat_message.dart';
import 'package:cerebro_mobile/features/graph/data/graph_pulse.dart';
import 'package:cerebro_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/network/fake_connection_status_notifier.dart';
import '../features/auth/fake_auth_repository.dart';
import '../features/documents/fake_documents_repository.dart';

void main() {
  late FakeAuthRepository fakeRepository;

  Widget buildApp({GraphApi? graph}) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeRepository),
        // Settings' "Connection" section (Milestone 1.3) calls the real
        // backend by default — faked here so nav tests unrelated to it
        // stay fast and network-free.
        connectionStatusProvider.overrideWith(
          () => FakeConnectionStatusNotifier(() async {}),
        ),
        // Documents (Milestone 2.1) calls the real generated client by
        // default — faked here for the same reason.
        documentsRepositoryProvider.overrideWithValue(
          FakeDocumentsRepository(),
        ),
        // The Graph screen (Milestone 4.1) calls the real backend too.
        graphApiProvider.overrideWithValue(graph ?? _EmptyGraphApi()),
        chatHistoryApiProvider.overrideWithValue(_ReplayHistory()),
      ],
      child: const CerebroApp(),
    );
  }

  setUp(() => fakeRepository = FakeAuthRepository(initialUserId: 'user-1'));
  tearDown(() => fakeRepository.dispose());

  testWidgets(
    'history opened before first Graph visit replays visibly on entry',
    (tester) async {
      await tester.pumpWidget(buildApp(graph: _ReplayGraph()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('app_nav_chat')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('chat_history')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Stored question'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Let the invisible automatic replay finish before Graph even exists.
      await tester.pump(replayInterval + const Duration(milliseconds: 100));
      expect(find.byType(GraphScreen), findsNothing);
      await tester.tap(find.byKey(const Key('app_nav_graph')));
      await tester.pump();
      expect(find.byKey(const Key('graph_loading')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const Key('graph_pulse_d1')), findsOneWidget);
      await tester.pump(replayInterval + pulseDuration);
      expect(find.byKey(const Key('graph_pulse_d1')), findsNothing);
    },
  );

  testWidgets('an authenticated user lands on Documents by default', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('documents_empty')), findsOneWidget);
    expect(find.byKey(const Key('app_nav_docs')), findsOneWidget);
  });

  testWidgets('tapping the Chat destination renders the Chat screen', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('app_nav_chat')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('chat_empty')), findsOneWidget);
  });

  testWidgets('tapping the Graph destination renders the Graph screen', (
    tester,
  ) async {
    // (historical) the wireframe's Graph screen never settled
    // (see graph_screen_test.dart) — bounded pumps only here, no
    // pumpAndSettle for the rest of this test once it's mounted.
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('app_nav_graph')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(GraphScreen), findsOneWidget);
  });

  testWidgets('tapping the Board destination renders the Board screen', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('app_nav_board')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Research Board'), findsOneWidget);
  });

  testWidgets('tapping the Play destination renders the Playground screen', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('app_nav_play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Token Playground'), findsOneWidget);
  });

  testWidgets('tapping the Settings destination renders the Settings screen', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('app_nav_settings')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Alex Stone'), findsOneWidget);
  });

  testWidgets('signing out from Settings redirects to Sign in', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('app_nav_settings')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The button is below the fold in Settings' ListView, so scroll it
    // into the tree first (ListView doesn't build offscreen children).
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings_sign_out')),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // Invoke the callback directly rather than a pixel-offset tap:
    // go_router's StatefulShellRoute keeps every branch's Navigator
    // mounted in an IndexedStack, which made a coordinate-based tap
    // here land on the wrong target — this still exercises the exact
    // same callback a real tap fires.
    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('settings_sign_out')),
    );
    button.onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('sign_in_submit')), findsOneWidget);
  });
}

class _EmptyGraphApi implements GraphApi {
  @override
  Future<List<GraphNodeData>> nodes() async => const [];

  @override
  Future<List<GraphEdgeData>> edges() async => const [];

  @override
  Future<List<DocumentChunk>> chunks(String documentId) async => const [];
}

class _ReplayGraph extends _EmptyGraphApi {
  @override
  Future<List<GraphNodeData>> nodes() async {
    await Future<void>.delayed(const Duration(seconds: 5));
    return const [
      GraphNodeData(id: 'd1', title: 'Document', x: 0, y: 0, status: 'ready'),
    ];
  }
}

class _ReplayHistory implements ChatHistoryApi {
  @override
  Future<List<ChatSessionSummary>> list() async => [
    ChatSessionSummary(
      id: 's1',
      createdAt: DateTime.utc(2026),
      preview: 'Stored question',
    ),
  ];
  @override
  Future<ChatHistory> messages(String id) async => const ChatHistory(
    messages: [
      ChatMessage(
        id: 1,
        role: ChatRole.assistant,
        text: 'Answer',
        retrievedDocumentIds: ['d1'],
      ),
    ],
  );
  @override
  Future<void> delete(String id) async {}
}
