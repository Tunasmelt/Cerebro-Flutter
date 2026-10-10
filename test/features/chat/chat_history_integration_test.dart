// Milestone 3.3 functional tests against the REAL backend: a real conversation
// survives an app restart (a brand-new ProviderContainer), can be reopened with
// its citations intact, deleted for real, and exported to a real Markdown file.
// Gated like the other real-backend suites: needs
// --dart-define=CEREBRO_TEST_EMAIL=... and CEREBRO_TEST_PASSWORD=... for a
// confirmed account. Costs real LLM calls; every chat session created is
// deleted afterwards.
import 'dart:convert';
import 'dart:io';

import 'package:cerebro_mobile/core/config/supabase_config.dart';
import 'package:cerebro_mobile/core/network/api_client.dart';
import 'package:cerebro_mobile/core/network/api_client_provider.dart';
import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/core/network/generated_api_client.dart';
import 'package:cerebro_mobile/core/network/session_token_provider.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/chat/data/chat_controller.dart';
import 'package:cerebro_mobile/features/chat/data/chat_export_service.dart';
import 'package:cerebro_mobile/features/chat/data/chat_history_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_message.dart';
import 'package:cerebro_mobile/features/chat/data/chat_sessions_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_sessions_list.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_client.dart';
import 'package:cerebro_mobile/features/chat/data/conversation_exporter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const _email = String.fromEnvironment('CEREBRO_TEST_EMAIL');
const _password = String.fromEnvironment('CEREBRO_TEST_PASSWORD');
const _gated = _email == '' || _password == '';

class _FixedToken implements SessionTokenProvider {
  _FixedToken(this.currentAccessToken);
  @override
  final String? currentAccessToken;
}

/// Writes the export where the test can read it back, instead of opening the
/// share sheet.
class _FileExporter implements ConversationExporter {
  File? written;
  @override
  Future<void> export({
    required String fileName,
    required String markdown,
  }) async {
    final dir = await Directory.systemTemp.createTemp('cerebro_export_');
    addTearDown(() => dir.delete(recursive: true));
    written = File('${dir.path}/$fileName')..writeAsStringSync(markdown);
  }
}

Future<String> _signIn() async {
  final response = await http.post(
    Uri.parse('${SupabaseConfig.url}/auth/v1/token?grant_type=password'),
    headers: {
      'apikey': SupabaseConfig.anonKey,
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'email': _email, 'password': _password}),
  );
  if (response.statusCode != 200) {
    throw StateError('test sign-in failed: ${response.statusCode}');
  }
  return (jsonDecode(response.body) as Map<String, dynamic>)['access_token']
      as String;
}

void main() {
  late String token;
  final sessions = <String>[];

  setUpAll(() async {
    if (_gated) return;
    token = await _signIn();
  });

  tearDownAll(() async {
    if (_gated) return;
    final api = buildGeneratedApiClient(tokenProvider: _FixedToken(token));
    for (final id in sessions) {
      await api.apiV1ChatSessionsSessionIdDelete(sessionId: id);
    }
  });

  void skip() => markTestSkipped(
    'needs --dart-define=CEREBRO_TEST_EMAIL=... and '
    '--dart-define=CEREBRO_TEST_PASSWORD=... (a confirmed test account)',
  );

  /// One "app launch": a fresh container wired to the real endpoints, holding
  /// no memory of any earlier one.
  ({ProviderContainer c, _FileExporter exporter}) launch() {
    final fixed = _FixedToken(token);
    final api = ApiClient(tokenProvider: fixed);
    final generated = buildGeneratedApiClient(tokenProvider: fixed);
    final exporter = _FileExporter();
    final c = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('real-user'),
        apiClientProvider.overrideWithValue(api),
        chatStreamApiProvider.overrideWithValue(DioChatStreamClient(api.dio)),
        chatSessionsApiProvider.overrideWithValue(
          ApiChatSessionsApi(generated),
        ),
        chatHistoryApiProvider.overrideWithValue(ApiChatHistoryApi(generated)),
        conversationExporterProvider.overrideWithValue(exporter),
      ],
    );
    addTearDown(c.dispose);
    return (c: c, exporter: exporter);
  }

  Future<ChatMessage> converse(ProviderContainer c, String question) async {
    await c.read(chatControllerProvider.notifier).send(question);
    final state = c.read(chatControllerProvider);
    sessions.add(state.sessionId!);
    final answer = state.messages.last;
    expect(
      answer.status,
      ChatMessageStatus.complete,
      reason: 'turn ended ${answer.status}: ${answer.error?.message}',
    );
    return answer;
  }

  test('a real conversation is still listed after a restart, and reopens with '
      'its history and citations', () async {
    if (_gated) return skip();
    final first = launch();
    final live = await converse(first.c, 'What kinds of documents do I have?');
    final sessionId = first.c.read(chatControllerProvider).sessionId!;

    // "Close the app": a brand-new container knows nothing.
    final second = launch();
    expect(second.c.read(chatControllerProvider).messages, isEmpty);

    // The history screen watches this provider while it is on screen.
    second.c.listen(chatSessionsListProvider, (_, _) {});
    final list = await second.c.read(chatSessionsListProvider.future);
    final summary = list.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => fail('the conversation is missing from the list'),
    );
    expect(summary.preview, 'What kinds of documents do I have?');

    final ctl = second.c.read(chatControllerProvider.notifier);
    ctl.openSession(summary);
    await _until(
      () => !second.c.read(chatControllerProvider).loading,
      reason: 'history never finished loading',
    );
    final restored = second.c.read(chatControllerProvider);
    expect(restored.loadError, isNull, reason: '${restored.loadError}');
    expect(restored.sessionId, sessionId);
    expect(restored.messages.map((m) => m.role), [
      ChatRole.user,
      ChatRole.assistant,
    ]);
    expect(restored.messages.first.text, 'What kinds of documents do I have?');
    final back = restored.messages.last;
    expect(back.status, ChatMessageStatus.complete);
    expect(back.text, live.text, reason: 'the answer changed on reload');
    expect(back.retrievedChunkIds, live.retrievedChunkIds);
    expect(back.citedDocuments, live.citedDocuments);

    // A follow-up on the reopened conversation continues the same session.
    await ctl.send('Which one is the largest?');
    final after = second.c.read(chatControllerProvider);
    expect(after.sessionId, sessionId);
    expect(after.messages, hasLength(4));
    expect(after.messages.last.status, ChatMessageStatus.complete);
    // ignore: avoid_print
    print(
      'RESTART: listed ${list.length} conversation(s); restored '
      '${restored.messages.length} messages, ${back.citedDocuments.length} '
      'citation(s) intact; follow-up continued session',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  test(
    'deleting a real conversation removes it from the list and the backend',
    () async {
      if (_gated) return skip();
      final app = launch();
      await converse(app.c, 'Say hello in one short sentence.');
      final sessionId = app.c.read(chatControllerProvider).sessionId!;

      app.c.listen(chatSessionsListProvider, (_, _) {});
      final list = app.c.read(chatSessionsListProvider.notifier);
      await app.c.read(chatSessionsListProvider.future);
      await list.refresh();
      expect(
        app.c.read(chatSessionsListProvider).requireValue.map((s) => s.id),
        contains(sessionId),
      );

      expect(await list.delete(sessionId), isNull);

      // Gone from the client list (and the open chat was cleared)…
      expect(
        app.c.read(chatSessionsListProvider).requireValue.map((s) => s.id),
        isNot(contains(sessionId)),
      );
      expect(app.c.read(chatControllerProvider).sessionId, isNull);
      expect(app.c.read(chatControllerProvider).messages, isEmpty);

      // …and from the backend: a fresh launch lists nothing of it, and its
      // messages 404.
      final fresh = launch();
      fresh.c.listen(chatSessionsListProvider, (_, _) {});
      final remote = await fresh.c.read(chatSessionsListProvider.future);
      expect(remote.map((s) => s.id), isNot(contains(sessionId)));
      final api = ApiChatHistoryApi(
        buildGeneratedApiClient(tokenProvider: _FixedToken(token)),
      );
      await expectLater(
        api.messages(sessionId),
        throwsA(
          isA<RequestRejectedException>().having(
            (e) => e.code,
            'code',
            'not_found',
          ),
        ),
      );
      // Deleting it again is still a success (already gone).
      expect(await list.delete(sessionId), isNull);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('exporting a real conversation writes a Markdown file that reflects the '
      'exchange', () async {
    if (_gated) return skip();
    final app = launch();
    final answer = await converse(app.c, 'What kinds of documents do I have?');
    final summary = ChatSessionSummary(
      id: app.c.read(chatControllerProvider).sessionId!,
      createdAt: DateTime.now(),
      preview: 'x',
    );

    await app.c.read(chatExportServiceProvider).exportSession(summary);

    final file = app.exporter.written!;
    expect(file.path, endsWith('.md'));
    final md = file.readAsStringSync();
    printOnFailure(md);
    expect(md, startsWith('# Chat — '));
    expect(md, contains('## You\n\nWhat kinds of documents do I have?'));
    expect(md, contains('## Cerebro'));
    expect(md, isNot(contains('[[chunk')), reason: 'raw markers leaked');
    expect(md, endsWith('\n'));
    expect(md, isNot(endsWith('\n\n')));

    // Citation chips survive as numbered footnotes with titled sources.
    if (answer.citedDocuments.isNotEmpty) {
      expect(md, contains('**Sources**'));
      expect(md, contains('[1]'));
    }
    // The export of the open conversation matches the stored one.
    final c2 = launch();
    c2.c.read(chatControllerProvider.notifier).openSession(summary);
    await _until(
      () => !c2.c.read(chatControllerProvider).loading,
      reason: 'history never finished loading',
    );
    expect(c2.c.read(chatControllerProvider).messages.last.text, answer.text);
    // ignore: avoid_print
    print('EXPORT: ${md.length} chars, ${file.path.split('/').last}');
  }, timeout: const Timeout(Duration(minutes: 3)));
}

Future<void> _until(bool Function() done, {required String reason}) async {
  for (var i = 0; i < 100; i++) {
    if (done()) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail(reason);
}
