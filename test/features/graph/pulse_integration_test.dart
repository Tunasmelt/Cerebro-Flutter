// Milestone 4.3 functional tests against the REAL backend:
//   1. ask real questions and compare, by machine, the documents the graph
//      pulsed with the documents the real SSE `retrieval` event named;
//   2. reopen that real conversation in a fresh container and confirm the
//      replay pulses the same documents, in the same order, from what the
//      server stored.
// Gated like the other real-backend suites: needs
// --dart-define=CEREBRO_TEST_EMAIL=... and CEREBRO_TEST_PASSWORD=... for a
// confirmed account, or runtime CEREBRO_TEST_ACCESS_TOKEN from an existing
// signed-in test session. Never print or commit the token. Costs real LLM
// calls; the test-created chat session is deleted.
import 'dart:convert';
import 'dart:io';

import 'package:cerebro_mobile/core/config/supabase_config.dart';
import 'package:cerebro_mobile/core/network/api_client.dart';
import 'package:cerebro_mobile/core/network/api_client_provider.dart';
import 'package:cerebro_mobile/core/network/generated_api_client.dart'
    as generated;
import 'package:cerebro_mobile/core/network/session_token_provider.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/chat/data/chat_controller.dart';
import 'package:cerebro_mobile/features/chat/data/chat_history_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_message.dart';
import 'package:cerebro_mobile/features/chat/data/chat_sessions_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_client.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_event.dart';
import 'package:cerebro_mobile/features/graph/data/graph_api.dart';
import 'package:cerebro_mobile/features/graph/data/graph_pulse.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const _email = String.fromEnvironment('CEREBRO_TEST_EMAIL');
const _password = String.fromEnvironment('CEREBRO_TEST_PASSWORD');
final _accessToken = Platform.environment['CEREBRO_TEST_ACCESS_TOKEN'] ?? '';
final _gated = _accessToken.isEmpty && (_email == '' || _password == '');

class _FixedToken implements SessionTokenProvider {
  _FixedToken(this.currentAccessToken);
  @override
  final String? currentAccessToken;
}

/// The real stream client, with every `retrieval` event that passes through it
/// written down — the independent record the pulses are compared against.
class _RecordingStream implements ChatStreamApi {
  _RecordingStream(this._inner);

  final ChatStreamApi _inner;
  final retrievals = <ChatRetrieval>[];

  @override
  Stream<ChatStreamEvent> stream({
    required String sessionId,
    required String query,
    String? documentId,
  }) => _inner.stream(sessionId: sessionId, query: query).map((event) {
    if (event is ChatRetrieval) retrievals.add(event);
    return event;
  });
}

Future<String> _signIn() async {
  if (_accessToken.isNotEmpty) return _accessToken;
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
  test('the graph pulses exactly the documents the real retrieval named, and a '
      'reopened conversation replays them, in order', () async {
    if (_gated) {
      return markTestSkipped(
        'needs --dart-define=CEREBRO_TEST_EMAIL=... and '
        '--dart-define=CEREBRO_TEST_PASSWORD=... (a confirmed test account)',
      );
    }
    final fixed = _FixedToken(await _signIn());
    final api = ApiClient(tokenProvider: fixed);
    final client = generated.buildGeneratedApiClient(tokenProvider: fixed);
    final graphApi = ApiGraphApi(client);
    final recorder = _RecordingStream(DioChatStreamClient(api.dio));

    ProviderContainer launch() {
      final c = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('real-user'),
          apiClientProvider.overrideWithValue(api),
          chatStreamApiProvider.overrideWithValue(recorder),
          chatSessionsApiProvider.overrideWithValue(ApiChatSessionsApi(client)),
          chatHistoryApiProvider.overrideWithValue(ApiChatHistoryApi(client)),
          graphApiProvider.overrideWithValue(graphApi),
        ],
      );
      addTearDown(c.dispose);
      c.listen(chatControllerProvider, (_, _) {});
      return c;
    }

    List<GraphPulse> record(ProviderContainer c) {
      final log = <GraphPulse>[];
      c.listen(graphPulseProvider, (_, next) {
        final p = next.pulse;
        if (p != null && (log.isEmpty || log.last.key != p.key)) log.add(p);
      });
      return log;
    }

    // ---- 1. live: two real questions, two real retrievals ----
    final live = launch();
    final livePulses = record(live);
    final chat = live.read(chatControllerProvider.notifier);
    await chat.send('How is authentication handled in Cerebro?');
    final sessionId = live.read(chatControllerProvider).sessionId!;
    addTearDown(() async {
      await client.apiV1ChatSessionsSessionIdDelete(sessionId: sessionId);
    });
    await chat.send('What does the retention marketing guide recommend?');
    expect(
      live.read(chatControllerProvider).messages.last.status,
      ChatMessageStatus.complete,
      reason: 'the second turn did not finish',
    );

    expect(recorder.retrievals, hasLength(2), reason: 'two turns, two events');
    expect(
      livePulses,
      hasLength(2),
      reason: 'one pulse per retrieval event, no more, no fewer',
    );
    final realDocuments = {for (final n in await graphApi.nodes()) n.id};
    for (var i = 0; i < 2; i++) {
      final named = recorder.retrievals[i].documentIds.toSet();
      expect(named, isNotEmpty, reason: 'turn $i retrieved nothing');
      expect(
        livePulses[i].documentIds.toSet(),
        named,
        reason: 'turn $i pulsed different documents than retrieval named',
      );
      expect(
        realDocuments.containsAll(named),
        isTrue,
        reason: 'a pulsed document is not on the graph',
      );
    }

    // Independent check: the graph's own chunk lists say which document each
    // retrieved chunk belongs to. The pulsed documents are exactly those.
    for (var i = 0; i < 2; i++) {
      final r = recorder.retrievals[i];
      final owners = <String>{};
      for (final documentId in r.documentIds.toSet()) {
        final chunks = await graphApi.chunks(documentId);
        final theirs = chunks.map((c) => c.id).toSet();
        final hit = r.chunkIds.where(theirs.contains).toList();
        expect(
          hit,
          isNotEmpty,
          reason:
              'pulsed document $documentId owns none of the chunks '
              'retrieval named (turn $i)',
        );
        owners.addAll(hit);
      }
      expect(
        owners,
        r.chunkIds.toSet(),
        reason: 'a retrieved chunk belongs to no pulsed document (turn $i)',
      );
    }

    // ---- 2. reopen in a fresh "app launch" and replay ----
    final reopened = launch();
    final replayPulses = record(reopened);
    await reopened
        .read(chatControllerProvider.notifier)
        .openSession(
          ChatSessionSummary(id: sessionId, createdAt: DateTime.now()),
        );
    final state = reopened.read(chatControllerProvider);
    expect(state.loadError, isNull, reason: '${state.loadError}');

    // What the server stored for each answer agrees with what streamed.
    final storedAnswers = state.messages
        .where((m) => m.role == ChatRole.assistant)
        .toList();
    expect(storedAnswers, hasLength(2));
    for (var i = 0; i < 2; i++) {
      expect(
        storedAnswers[i].retrievedChunkIds,
        recorder.retrievals[i].chunkIds.toSet(),
        reason: 'stored chunk ids differ from the live retrieval (turn $i)',
      );
      expect(
        storedAnswers[i].retrievedDocumentIds.toSet(),
        recorder.retrievals[i].documentIds.toSet(),
        reason:
            'stored document ids differ from the live retrieval '
            '(turn $i)',
      );
    }

    // Opening history starts replay automatically, as Chat History does.
    // Allow each stored answer its actual production animation interval.
    final replayDeadline = DateTime.now().add(const Duration(seconds: 15));
    while (reopened.read(graphPulseProvider).replaying &&
        DateTime.now().isBefore(replayDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(reopened.read(graphPulseProvider).replaying, isFalse);

    expect(
      replayPulses.map((p) => p.documentIds.toSet()).toList(),
      livePulses.map((p) => p.documentIds.toSet()).toList(),
      reason:
          'the replay pulsed different documents than the live turns, '
          'or in a different order',
    );

    // ignore: avoid_print
    print(
      'PULSE CHECK: ${livePulses.length} live pulses '
      '(${livePulses.map((p) => p.documentIds.length).join(' + ')} documents) '
      'matched the real SSE retrieval events exactly; the reopened '
      'conversation replayed the same ${replayPulses.length} pulses in order',
    );
  }, timeout: const Timeout(Duration(minutes: 6)));
}
