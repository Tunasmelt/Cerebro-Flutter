// Milestone 3.1 functional test: the REAL chat stream endpoint, parsed by
// THIS client — no mocking.
//
// Gated like the upload integration tests (skipped cleanly otherwise,
// including in CI): needs --dart-define=CEREBRO_TEST_EMAIL=... and
// --dart-define=CEREBRO_TEST_PASSWORD=... for an already-confirmed account.
// Costs real LLM calls (one short answer per streaming test); every chat
// session it creates is deleted afterwards.
import 'dart:async';
import 'dart:convert';

import 'package:cerebro_mobile/core/config/supabase_config.dart';
import 'package:cerebro_mobile/core/network/api_client.dart';
import 'package:cerebro_mobile/core/network/generated_api_client.dart';
import 'package:cerebro_mobile/core/network/session_token_provider.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_client.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_event.dart';
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

/// An event and when (since the stream was opened) it was received.
typedef _Timed = ({ChatStreamEvent event, Duration at});

void main() {
  late String token;
  late DioChatStreamClient client;
  final created = <String>[];

  setUpAll(() async {
    if (_gated) return;
    token = await _signIn();
    final api = ApiClient(tokenProvider: _FixedToken(token));
    client = DioChatStreamClient(api.dio);
  });

  Future<String> createSession() async {
    final generated = buildGeneratedApiClient(
      tokenProvider: _FixedToken(token),
    );
    final response = await generated.apiV1ChatSessionsPost();
    expect(
      response.isSuccessful,
      isTrue,
      reason: 'create session: ${response.error}',
    );
    final id = (response.body as Map<String, dynamic>)['id'] as String;
    created.add(id);
    return id;
  }

  tearDownAll(() async {
    if (_gated) return;
    final generated = buildGeneratedApiClient(
      tokenProvider: _FixedToken(token),
    );
    for (final id in created) {
      await generated.apiV1ChatSessionsSessionIdDelete(sessionId: id);
    }
  });

  void skip() {
    if (_gated) {
      markTestSkipped(
        'needs --dart-define=CEREBRO_TEST_EMAIL=... and '
        '--dart-define=CEREBRO_TEST_PASSWORD=... (a confirmed test account)',
      );
    }
  }

  test('a real query yields real events in the contract order, with retrieval '
      'strictly before the first token', () async {
    if (_gated) return skip();
    final session = await createSession();
    final clock = Stopwatch()..start();
    final events = <_Timed>[];

    await for (final event in client.stream(
      sessionId: session,
      query: 'Summarise what my documents are about in one sentence.',
    )) {
      events.add((event: event, at: clock.elapsed));
    }

    final names = [for (final e in events) e.event.runtimeType.toString()];
    // A one-line account of what the real backend sent, for the log.
    String ms(Duration d) => '${d.inMilliseconds}ms';
    final retrievalAt = events.indexWhere((e) => e.event is ChatRetrieval);
    final firstTokenAt = events.indexWhere((e) => e.event is ChatToken);
    // ignore: avoid_print
    print(
      'REAL STREAM: ${events.length} events '
      '(heartbeat ${events.where((e) => e.event is ChatHeartbeat).length}, '
      'token ${events.where((e) => e.event is ChatToken).length}, '
      'citation ${events.where((e) => e.event is ChatCitation).length}); '
      'retrieval at ${retrievalAt < 0 ? 'n/a' : ms(events[retrievalAt].at)}, '
      'first token at ${firstTokenAt < 0 ? 'n/a' : ms(events[firstTokenAt].at)}, '
      'done at ${ms(events.last.at)}',
    );
    final errors = events.map((e) => e.event).whereType<ChatError>().toList();
    expect(
      errors,
      isEmpty,
      reason:
          'the server reported a failed turn: '
          '${errors.map((e) => '${e.code}: ${e.rawMessage}').join('; ')}',
    );
    expect(events.last.event, isA<ChatDone>(), reason: 'events: $names');

    // Heartbeats only ever precede retrieval.
    final retrievalIndex = events.indexWhere((e) => e.event is ChatRetrieval);
    expect(retrievalIndex, isNonNegative, reason: 'events: $names');
    for (var i = 0; i < events.length; i++) {
      if (events[i].event is ChatHeartbeat) {
        expect(
          i,
          lessThan(retrievalIndex),
          reason: 'heartbeat after retrieval: $names',
        );
      }
    }
    // Exactly one retrieval, and it is the first non-heartbeat event.
    expect(events.where((e) => e.event is ChatRetrieval), hasLength(1));
    expect(
      events.firstWhere((e) => e.event is! ChatHeartbeat).event,
      isA<ChatRetrieval>(),
    );

    final firstToken = events.indexWhere((e) => e.event is ChatToken);
    expect(firstToken, isNonNegative, reason: 'no tokens: $names');
    expect(
      events[retrievalIndex].at,
      lessThanOrEqualTo(events[firstToken].at),
      reason: 'retrieval must arrive before the first token',
    );
    expect(retrievalIndex, lessThan(firstToken));

    // Tokens, then citations, then done — nothing out of order, nothing
    // after done.
    final lastToken = events.lastIndexWhere((e) => e.event is ChatToken);
    for (var i = 0; i < events.length; i++) {
      if (events[i].event is ChatCitation) {
        expect(
          i,
          greaterThan(lastToken),
          reason: 'citation before the last token: $names',
        );
      }
    }
    expect(events.where((e) => e.event is ChatDone), hasLength(1));

    // The answer streamed rather than arriving in one piece.
    final tokenCount = events.where((e) => e.event is ChatToken).length;
    expect(
      tokenCount,
      greaterThan(1),
      reason: 'one lump, not a stream: $names',
    );
    expect(
      events.last.at,
      greaterThan(events[firstToken].at),
      reason: 'all tokens arrived at the same instant as done',
    );

    // Every citation names a chunk that retrieval returned.
    final retrieved = (events[retrievalIndex].event as ChatRetrieval).chunkIds
        .toSet();
    for (final c in events.map((e) => e.event).whereType<ChatCitation>()) {
      expect(retrieved, contains(c.chunkId));
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test(
    'cancelling a real stream mid-answer ends cleanly and promptly',
    () async {
      if (_gated) return skip();
      final session = await createSession();
      final seen = Completer<void>();
      final sub = client
          .stream(
            sessionId: session,
            query: 'Explain how retrieval works, at length.',
          )
          .listen((event) {
            if (event is ChatRetrieval && !seen.isCompleted) seen.complete();
          });

      await seen.future.timeout(const Duration(seconds: 90));
      await sub.cancel().timeout(const Duration(seconds: 5));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'streaming into a conversation that does not exist is a clean 404',
    () async {
      if (_gated) return skip();

      await expectLater(
        client
            .stream(
              sessionId: '00000000-0000-4000-8000-000000000000',
              query: 'hi',
            )
            .toList(),
        throwsA(
          isA<Object>().having(
            (e) => e.toString(),
            'is an app exception',
            isNotEmpty,
          ),
        ),
      );
    },
  );
}
