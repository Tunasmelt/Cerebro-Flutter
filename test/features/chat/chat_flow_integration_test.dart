// Milestone 3.2 functional tests: the REAL conversation flow — the chat
// controller on the real chat endpoint, real retrieval, a real model — with
// nothing mocked. Gated like the other real-backend suites: needs
// --dart-define=CEREBRO_TEST_EMAIL=... and CEREBRO_TEST_PASSWORD=... for a
// confirmed account that already has some READY documents. Costs real LLM
// calls; every chat session created is deleted afterwards.
import 'dart:async';
import 'dart:convert';

import 'package:cerebro_mobile/core/config/supabase_config.dart';
import 'package:cerebro_mobile/core/network/api_client.dart';
import 'package:cerebro_mobile/core/network/api_client_provider.dart';
import 'package:cerebro_mobile/core/network/generated_api_client.dart';
import 'package:cerebro_mobile/core/network/session_token_provider.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/chat/data/answer_segments.dart';
import 'package:cerebro_mobile/features/chat/data/chat_controller.dart';
import 'package:cerebro_mobile/features/chat/data/chat_message.dart';
import 'package:cerebro_mobile/features/chat/data/chat_sessions_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_client.dart';
import 'package:cerebro_mobile/features/chat/data/resolved_answer.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository.dart';
import 'package:cerebro_mobile/features/documents/data/upload/picked_upload.dart';
import 'package:cerebro_mobile/features/documents/data/upload/storage_uploader.dart';
import 'package:cerebro_mobile/features/documents/data/upload/upload_api.dart';
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
  late DocumentsRepository documents;
  final sessions = <String>[];

  setUpAll(() async {
    if (_gated) return;
    token = await _signIn();
    documents = ApiDocumentsRepository(
      buildGeneratedApiClient(tokenProvider: _FixedToken(token)),
    );
  });

  tearDownAll(() async {
    if (_gated) return;
    final api = buildGeneratedApiClient(tokenProvider: _FixedToken(token));
    for (final id in sessions) {
      await api.apiV1ChatSessionsSessionIdDelete(sessionId: id);
    }
  });

  /// Uploads a small document containing facts no other document has, waits
  /// until it is READY, and deletes it when the test ends.
  Future<String> uploadDistinctiveDocument() async {
    final fixed = _FixedToken(token);
    final generated = buildGeneratedApiClient(tokenProvider: fixed);
    final bytes = utf8.encode(
      'Field notes on the Zanzibar Protocol.\n\n'
      'The Zanzibar Protocol was invented by Dr. Ilse Quartermain in 1987. '
      'It synchronises seven-sided purple widgets across the Lisbon relay '
      'network. Its single known weakness is a clock drift of exactly '
      '41 milliseconds per hour.\n',
    );
    final file = PickedUpload(
      name: 'zanzibar-field-notes.txt',
      mime: 'text/plain',
      sizeBytes: bytes.length,
      openRead: () => Stream<List<int>>.value(bytes),
    );
    final uploadApi = ApiUploadApi(generated);
    final init = await uploadApi.init(
      filename: file.name,
      mime: 'text/plain',
      sizeBytes: file.sizeBytes,
    );
    addTearDown(() async {
      await generated.apiV1DocumentsDocumentIdDelete(
        documentId: init.documentId,
      );
    });
    await DioStorageUploader(
      tokenProvider: fixed,
      apiKey: SupabaseConfig.anonKey,
    ).put(uploadUrl: init.uploadUrl, file: file, mime: 'text/plain');
    await uploadApi.confirm(init.documentId);

    for (var i = 0; i < 90; i++) {
      final detail = await documents.getDocument(init.documentId);
      if (detail.status == DocumentStatus.ready) return init.documentId;
      if (detail.status == DocumentStatus.failed) {
        fail('the test document failed to ingest: ${detail.lastError}');
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    fail('the test document never became ready');
  }

  void skip() {
    if (_gated) {
      markTestSkipped(
        'needs --dart-define=CEREBRO_TEST_EMAIL=... and '
        '--dart-define=CEREBRO_TEST_PASSWORD=... (a confirmed test account)',
      );
    }
  }

  /// A container wired to the REAL chat endpoints, recording every state the
  /// conversation passes through (with when).
  ({ProviderContainer c, List<(Duration, ChatMessage)> trace}) realChat() {
    final fixed = _FixedToken(token);
    final api = ApiClient(tokenProvider: fixed);
    final c = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('real-user'),
        apiClientProvider.overrideWithValue(api),
        chatStreamApiProvider.overrideWithValue(DioChatStreamClient(api.dio)),
        chatSessionsApiProvider.overrideWithValue(
          ApiChatSessionsApi(buildGeneratedApiClient(tokenProvider: fixed)),
        ),
      ],
    );
    addTearDown(c.dispose);
    final clock = Stopwatch()..start();
    final trace = <(Duration, ChatMessage)>[];
    c.listen(chatControllerProvider, (_, next) {
      if (next.messages.isNotEmpty) {
        trace.add((clock.elapsed, next.messages.last));
      }
    });
    return (c: c, trace: trace);
  }

  test('a real question about real documents streams in progressively and its '
      'citation chips resolve to real, existing source documents', () async {
    if (_gated) return skip();
    // A real, previously-uploaded document with facts no other one has.
    final documentId = await uploadDistinctiveDocument();
    final real = await documents.listDocuments();
    expect(real.map((d) => d.id), contains(documentId));

    final (:c, :trace) = realChat();
    await c
        .read(chatControllerProvider.notifier)
        .send('Who invented the Zanzibar Protocol, and what is its weakness?');
    sessions.add(c.read(chatControllerProvider).sessionId!);

    final answer = c.read(chatControllerProvider).messages.last;
    printOnFailure(
      'ANSWER TEXT: ${answer.text}\n'
      'RETRIEVED: ${answer.retrievedChunkIds}\n'
      'CITED: ${answer.citedDocuments}',
    );
    expect(
      answer.status,
      ChatMessageStatus.complete,
      reason: 'turn ended ${answer.status}: ${answer.error?.message}',
    );

    // Progressive: the text grew through several distinct states, and the
    // first words were on screen before the turn finished.
    final lengths = <int>[];
    for (final (_, m) in trace) {
      if (lengths.isEmpty || m.text.length != lengths.last) {
        lengths.add(m.text.length);
      }
    }
    final growing = lengths.where((l) => l > 0).toList();
    expect(
      growing.length,
      greaterThan(1),
      reason: 'one lump, not a stream: $lengths',
    );
    final firstText = trace.firstWhere((t) => t.$2.text.isNotEmpty);
    final completed = trace.firstWhere(
      (t) => t.$2.status == ChatMessageStatus.complete,
    );
    expect(firstText.$1, lessThan(completed.$1));
    expect(
      firstText.$2.isStreaming,
      isTrue,
      reason: 'text must appear while the turn is still running',
    );

    // Citations: the chips resolved from the real events point at documents
    // that really exist in this account.
    final parts = resolveAnswer(
      parseAnswerSegments(answer.text),
      retrievedChunkIds: answer.retrievedChunkIds,
      citedDocuments: answer.citedDocuments,
    );
    final chips = parts.whereType<ChipPart>().toList();
    expect(chips, isNotEmpty, reason: 'no citation chip for: ${answer.text}');
    // The answer is actually about that document, and a chip opens THAT one.
    expect(answer.text, contains('Quartermain'));
    expect(
      chips.map((chip) => chip.documentId),
      contains(documentId),
      reason: 'no chip points at the document the question was about',
    );
    final realIds = real.map((d) => d.id).toSet();
    for (final chip in chips) {
      expect(
        realIds,
        contains(chip.documentId),
        reason: 'chip ${chip.number} points at a document that does not exist',
      );
    }
    // …and none of the raw marker syntax survived into the drawable text.
    final drawn = parts.whereType<TextPart>().map((p) => p.text).join();
    expect(drawn, isNot(contains('[[chunk:')));
    expect(drawn, isNotEmpty);

    // ignore: avoid_print
    print(
      'REAL ANSWER: ${answer.text.length} chars in ${growing.length} '
      'progressive states, ${chips.length} chips -> '
      '${chips.map((c) => c.documentId).toSet().length} document(s)',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test(
    'a follow-up in the same conversation reuses the session',
    () async {
      if (_gated) return skip();
      final (:c, trace: _) = realChat();
      final ctl = c.read(chatControllerProvider.notifier);

      await ctl.send('What kinds of documents do I have?');
      final first = c.read(chatControllerProvider).sessionId;
      sessions.add(first!);
      await ctl.send('Which of them is the biggest?');

      final state = c.read(chatControllerProvider);
      expect(state.sessionId, first);
      expect(state.messages, hasLength(4));
      expect(
        state.messages.last.status,
        ChatMessageStatus.complete,
        reason: '${state.messages.last.error?.message}',
      );
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'a question with nothing relevant behind it: what retrieval really does',
    () async {
      if (_gated) return skip();
      final (:c, trace: _) = realChat();
      await c
          .read(chatControllerProvider.notifier)
          .send('zxqv wlmn 8472 qqqq blorptastic quuxification');
      sessions.add(c.read(chatControllerProvider).sessionId!);

      final answer = c.read(chatControllerProvider).messages.last;
      expect(answer.retrievalDone, isTrue);
      expect(
        answer.status,
        ChatMessageStatus.complete,
        reason: '${answer.error?.message}',
      );
      // The app must be consistent with whatever retrieval reported: it flags
      // "no matching documents" exactly when retrieval returned nothing.
      expect(answer.retrievalFoundNothing, answer.retrievedChunkIds.isEmpty);
      // ignore: avoid_print
      print(
        'NONSENSE QUERY: retrieval returned '
        '${answer.retrievedChunkIds.length} chunk(s) -> '
        '${answer.retrievalFoundNothing ? 'UI shows "No matching documents"' : 'UI shows a normal (grounded-looking) answer'}',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
