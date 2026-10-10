// Milestone 3.3 audit: defects reproduced against the real classes.
import 'dart:async';
import 'dart:io';

import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/chat/data/chat_controller.dart';
import 'package:cerebro_mobile/features/chat/data/chat_export_service.dart';
import 'package:cerebro_mobile/features/chat/data/chat_history_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_message.dart';
import 'package:cerebro_mobile/features/chat/data/chat_sessions_list.dart';
import 'package:cerebro_mobile/features/chat/data/conversation_exporter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _GatedHistory implements ChatHistoryApi {
  final gate = Completer<void>();
  @override
  Future<List<ChatSessionSummary>> list() async => [
    ChatSessionSummary(id: 's1', createdAt: DateTime.utc(2026), preview: 'Q'),
  ];
  @override
  Future<ChatHistory> messages(String id) async =>
      ChatHistory(messages: [ChatMessage.user(id: 0, text: 'Q')]);
  @override
  Future<void> delete(String id) => gate.future;
}

void main() {
  test(
    'leaving the history screen mid-delete must not break the delete',
    () async {
      final history = _GatedHistory();
      final c = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('u'),
          chatHistoryApiProvider.overrideWithValue(history),
        ],
      );
      addTearDown(c.dispose);
      c.listen(chatControllerProvider, (_, _) {});
      // The open chat IS the conversation being deleted.
      c
          .read(chatControllerProvider.notifier)
          .openSession(
            ChatSessionSummary(id: 's1', createdAt: DateTime.utc(2026)),
          );
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // The history screen is on screen (listening), then the user taps delete…
      final sub = c.listen(chatSessionsListProvider, (_, _) {});
      await c.read(chatSessionsListProvider.future);
      final deleting = c.read(chatSessionsListProvider.notifier).delete('s1');
      // …and immediately navigates back: nothing listens any more.
      sub.close();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      history.gate.complete();

      expect(await deleting, isNull);
      expect(
        c.read(chatControllerProvider).sessionId,
        isNull,
        reason: 'the deleted conversation is still open in Chat',
      );
    },
  );

  group('the shared file', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('cerebro_audit_'));
    tearDown(() => dir.deleteSync(recursive: true));

    ShareConversationExporter exporter(ShareFile share) =>
        ShareConversationExporter(directory: () async => dir, share: share);

    test(
      'exists while the share sheet runs, and is deleted afterwards',
      () async {
        String? seen;
        await exporter((file, name) async {
          expect(file.existsSync(), isTrue);
          seen = file.readAsStringSync();
        }).export(fileName: 'a.md', markdown: '# secret');

        expect(seen, '# secret');
        expect(
          dir.listSync(),
          isEmpty,
          reason: 'conversation left in the cache',
        );
      },
    );

    test('is deleted even when sharing fails', () async {
      await expectLater(
        exporter(
          (_, _) async => throw StateError('no share target'),
        ).export(fileName: 'a.md', markdown: 'x'),
        throwsStateError,
      );
      expect(dir.listSync(), isEmpty);
    });
  });

  test(
    'a conversation with no messages says there is nothing to export',
    () async {
      final exported = <String>[];
      final c = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('u'),
          chatHistoryApiProvider.overrideWithValue(_EmptyHistory()),
          conversationExporterProvider.overrideWithValue(_Recorder(exported)),
        ],
      );
      addTearDown(c.dispose);
      await expectLater(
        c
            .read(chatExportServiceProvider)
            .exportSession(
              ChatSessionSummary(id: 'e', createdAt: DateTime.utc(2026)),
            ),
        throwsA(
          isA<UnknownApiException>().having(
            (e) => e.message,
            'message',
            contains('nothing to export'),
          ),
        ),
      );
      expect(exported, isEmpty);
    },
  );
}

class _EmptyHistory extends _GatedHistory {
  @override
  Future<ChatHistory> messages(String id) async =>
      const ChatHistory(messages: []);
}

class _Recorder implements ConversationExporter {
  _Recorder(this.out);
  final List<String> out;
  @override
  Future<void> export({
    required String fileName,
    required String markdown,
  }) async => out.add(markdown);
}
