import 'package:cerebro_mobile/core/network/connection_status_notifier.dart';
import 'package:cerebro_mobile/features/auth/data/auth_notifier.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/auth/presentation/sign_in_screen.dart';
import 'package:cerebro_mobile/features/auth/presentation/sign_up_screen.dart';
import 'package:cerebro_mobile/features/chat/data/chat_controller.dart';
import 'package:cerebro_mobile/features/chat/data/chat_history_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_sessions_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_client.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_event.dart';
import 'package:cerebro_mobile/features/chat/presentation/chat_screen.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/documents/presentation/documents_screen.dart';
import 'package:cerebro_mobile/features/graph/data/graph_api.dart';
import 'package:cerebro_mobile/features/graph/data/graph_models.dart';
import 'package:cerebro_mobile/features/graph/presentation/graph_screen.dart';
import 'package:cerebro_mobile/features/kanban/data/kanban_api.dart';
import 'package:cerebro_mobile/features/kanban/presentation/board_screen.dart';
import 'package:cerebro_mobile/features/settings/data/account_settings.dart';
import 'package:cerebro_mobile/features/settings/presentation/account_settings_screen.dart';
import 'package:cerebro_mobile/features/settings/presentation/settings_screen.dart';
import 'package:cerebro_mobile/features/todo/data/todo_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/network/fake_connection_status_notifier.dart';
import '../features/auth/fake_auth_repository.dart';
import '../features/documents/fake_documents_repository.dart';
import '../features/kanban/fake_kanban_api.dart';
import '../features/todo/fake_todo_api.dart';
import 'qa_harness.dart';

/// One QA pass over every main screen: the same checks at every size and text
/// scale. Add a screen here and it gets all of them.
///
/// What it enforces (each failure names the screen, size and scale):
/// - nothing overflows or throws, from a 320px phone to a tablet, at normal and
///   large text;
/// - tappable things are at least the iOS 44pt target (the app's own floor);
/// - every tappable thing has a label a screen reader can speak.
/// Text contrast is measured separately (test/shared/app_contrast_test.dart,
/// from the tokens) rather than from screenshots, which are slow and noisy.

class _QaGraph implements GraphApi {
  @override
  Future<List<GraphNodeData>> nodes() async => [
    for (var i = 0; i < 8; i++)
      GraphNodeData(
        id: 'n$i',
        title: 'Document number $i',
        x: (i - 4) / 4,
        y: (i.isEven ? 0.4 : -0.4),
        mime: i == 3 ? 'image/png' : 'text/plain',
        status: i == 5 ? 'sealed' : 'ready',
        clusterId: 'c1',
      ),
  ];

  @override
  Future<List<GraphEdgeData>> edges() async => const [];

  @override
  Future<List<DocumentChunk>> chunks(String documentId) async => const [];
}

class _QaChatStream implements ChatStreamApi {
  @override
  Stream<ChatStreamEvent> stream({
    required String sessionId,
    required String query,
    String? documentId,
  }) => const Stream.empty();
}

class _QaSessions implements ChatSessionsApi {
  @override
  Future<String> create() async => 'qa-session';
}

class _QaHistory implements ChatHistoryApi {
  @override
  Future<List<ChatSessionSummary>> list() async => const [];

  @override
  Future<ChatHistory> messages(String id) async =>
      const ChatHistory(messages: []);

  @override
  Future<void> delete(String id) async {}
}

DocumentSummary _doc(String id, String title, DocumentStatus status) =>
    DocumentSummary(
      id: id,
      title: title,
      mime: 'application/pdf',
      sizeBytes: 2048,
      originalSizeBytes: 2048,
      status: status,
      createdAt: DateTime.utc(2026, 1, 1),
    );

List<QaScreen> _screens() {
  final auth = FakeAuthRepository();
  return [
    QaScreen(
      name: 'Sign in',
      home: const SignInScreen(),
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    ),
    QaScreen(
      name: 'Sign up',
      home: const SignUpScreen(),
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    ),
    QaScreen(
      name: 'Documents',
      home: const DocumentsScreen(),
      overrides: [
        currentUserIdProvider.overrideWithValue('qa'),
        documentsRepositoryProvider.overrideWithValue(
          FakeDocumentsRepository(
            documents: [
              _doc(
                '1',
                'A fairly long research paper title.pdf',
                DocumentStatus.ready,
              ),
              _doc('2', 'Meeting notes', DocumentStatus.processing),
              _doc('3', 'Vault', DocumentStatus.sealed),
              _doc('4', 'Broken upload', DocumentStatus.failed),
            ],
          ),
        ),
      ],
    ),
    QaScreen(
      name: 'Board',
      home: const BoardScreen(),
      overrides: [
        currentUserIdProvider.overrideWithValue('qa'),
        kanbanApiProvider.overrideWithValue(FakeKanbanApi()),
        todoApiProvider.overrideWithValue(FakeTodoApi()),
        documentsRepositoryProvider.overrideWithValue(
          FakeDocumentsRepository(),
        ),
      ],
    ),
    QaScreen(
      name: 'Settings',
      home: const SettingsScreen(),
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        connectionStatusProvider.overrideWith(
          () => FakeConnectionStatusNotifier(() async {}),
        ),
      ],
    ),
    QaScreen(
      name: 'Chat',
      home: ChatScreen(openDocument: (_, _) {}),
      overrides: [
        currentUserIdProvider.overrideWithValue('qa'),
        chatStreamApiProvider.overrideWithValue(_QaChatStream()),
        chatSessionsApiProvider.overrideWithValue(_QaSessions()),
        chatHistoryApiProvider.overrideWithValue(_QaHistory()),
        documentsRepositoryProvider.overrideWithValue(
          FakeDocumentsRepository(
            documents: [
              _doc('1', 'Quarterly report.pdf', DocumentStatus.ready),
              _doc(
                '2',
                'A much longer document title that will wrap.pdf',
                DocumentStatus.ready,
              ),
            ],
          ),
        ),
      ],
    ),
    QaScreen(
      name: 'Account settings',
      home: const AccountSettingsScreen(
        account: SettingsAccount(id: 'qa', email: 'qa@example.com', name: 'QA'),
      ),
      overrides: [currentUserIdProvider.overrideWithValue('qa')],
    ),
    QaScreen(
      name: 'Graph',
      home: const GraphScreen(),
      overrides: [
        currentUserIdProvider.overrideWithValue('qa'),
        graphApiProvider.overrideWithValue(_QaGraph()),
      ],
    ),
  ];
}

void main() {
  for (final screen in _screens()) {
    group(screen.name, () {
      for (final MapEntry(key: shape, value: size) in qaSizes.entries) {
        for (final scale in qaTextScales) {
          final where =
              '${screen.name} @ $shape ${size.width.toInt()}px, '
              'text x$scale';

          testWidgets('lays out without error: $shape, text x$scale', (
            tester,
          ) async {
            await pumpQaScreen(tester, screen, size: size, textScale: scale);
            expectNoLayoutError(tester, where);
          });
        }
      }

      testWidgets('tap targets are at least 44pt, with labels', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpQaScreen(tester, screen, size: qaSizes['phone']!);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    });
  }
}
