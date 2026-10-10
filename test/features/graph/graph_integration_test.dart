// Milestone 4.1 functional test against the REAL backend: the user's real
// graph maps into the package's graph with one node per real document. Gated
// like the other real-backend suites: needs
// --dart-define=CEREBRO_TEST_EMAIL=... and CEREBRO_TEST_PASSWORD=... for a
// confirmed account. Read-only: it never reclusters or changes anything.
import 'dart:convert';

import 'package:cerebro_mobile/core/config/supabase_config.dart';
import 'package:cerebro_mobile/core/network/api_client.dart';
import 'package:cerebro_mobile/core/network/api_client_provider.dart';
import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/core/network/generated_api_client.dart';
import 'package:cerebro_mobile/core/network/session_token_provider.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/chat/data/chat_controller.dart';
import 'package:cerebro_mobile/features/chat/data/chat_sessions_api.dart';
import 'package:cerebro_mobile/features/chat/data/chat_stream_client.dart';
import 'package:cerebro_mobile/core/network/generated_api_client.dart' as gen;
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository.dart';
import 'package:cerebro_mobile/features/graph/data/graph_api.dart';
import 'package:cerebro_mobile/features/graph/data/graph_expansion.dart';
import 'package:cerebro_mobile/features/graph/data/graph_layout.dart';
import 'package:cerebro_mobile/features/graph/data/graph_models.dart';
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
  test('the real graph has one node per real document, and maps into the '
      "package's graph", () async {
    if (_gated) {
      return markTestSkipped(
        'needs --dart-define=CEREBRO_TEST_EMAIL=... and '
        '--dart-define=CEREBRO_TEST_PASSWORD=... (a confirmed test account)',
      );
    }
    final generated = buildGeneratedApiClient(
      tokenProvider: _FixedToken(await _signIn()),
    );
    final graphApi = ApiGraphApi(generated);
    final documents = await ApiDocumentsRepository(generated).listDocuments();

    final nodes = await graphApi.nodes();
    final edges = await graphApi.edges();
    final snapshot = GraphSnapshot(nodes: nodes, edges: edges);

    // The graph lists every ready document and every sealed one.
    final shown = documents
        .where(
          (d) =>
              d.status == DocumentStatus.ready ||
              d.status == DocumentStatus.sealed,
        )
        .toList();
    printOnFailure(
      'documents=${documents.length} shown=${shown.length} '
      'nodes=${nodes.length} edges=${edges.length}',
    );
    expect(nodes.map((n) => n.id).toSet(), hasLength(nodes.length));
    expect(
      nodes.map((n) => n.id).toSet(),
      shown.map((d) => d.id).toSet(),
      reason: 'the graph and the Documents tab disagree about what exists',
    );

    // Types agree with the document list's own view of each document.
    final byId = {for (final d in documents) d.id: d};
    for (final n in nodes) {
      final d = byId[n.id]!;
      expect(
        n.type == GraphNodeType.sealed,
        d.status == DocumentStatus.sealed,
        reason: '${n.title}: sealed mismatch',
      );
      expect(
        n.type == GraphNodeType.image,
        d.status != DocumentStatus.sealed && d.mime.startsWith('image/'),
        reason: '${n.title}: image mismatch',
      );
    }

    // And it maps into the package's graph, one node each.
    final graph = buildForceGraph(snapshot);
    expect(graph.nodes, hasLength(nodes.length));
    for (final n in graph.nodes) {
      expect(n.position.x.isFinite && n.position.y.isFinite, isTrue);
    }
    // ignore: avoid_print
    print(
      'REAL GRAPH: ${documents.length} documents -> ${nodes.length} nodes '
      '(${nodes.where((n) => n.type == GraphNodeType.image).length} image, '
      '${nodes.where((n) => n.type == GraphNodeType.sealed).length} sealed), '
      '${edges.length} edges, clustered=${snapshot.isClustered}; mapped '
      '${graph.nodes.length} nodes / ${graph.edges.length} edges',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test("expanding every real document loads its real chunks, and a cited chunk "
      "is in its document's list", () async {
    if (_gated) {
      return markTestSkipped(
        'needs --dart-define=CEREBRO_TEST_EMAIL=... and '
        '--dart-define=CEREBRO_TEST_PASSWORD=... (a confirmed test account)',
      );
    }
    final token = await _signIn();
    final fixed = _FixedToken(token);
    final generated = gen.buildGeneratedApiClient(tokenProvider: fixed);
    final api = ApiClient(tokenProvider: fixed);
    final graphApi = ApiGraphApi(generated);
    final c = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('real-user'),
        graphApiProvider.overrideWithValue(graphApi),
        apiClientProvider.overrideWithValue(api),
        chatStreamApiProvider.overrideWithValue(DioChatStreamClient(api.dio)),
        chatSessionsApiProvider.overrideWithValue(
          ApiChatSessionsApi(generated),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(graphExpansionProvider, (_, _) {});
    final ctl = c.read(graphExpansionProvider.notifier);

    final nodes = await graphApi.nodes();
    final lines = <String>[];
    final chunksByDoc = <String, Set<String>>{};
    for (final n in nodes) {
      await ctl.toggle(n.id);
      final s = c.read(graphExpansionProvider);
      expect(s.nodeId, n.id);
      expect(
        s.load,
        ChunkLoad.loaded,
        reason: '${n.title}: ${s.error?.message}',
      );

      // Unique ids, in reading order.
      final ids = s.chunks.map((x) => x.id).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: n.title);
      for (var i = 1; i < s.chunks.length; i++) {
        expect(
          s.chunks[i].ordinal,
          greaterThanOrEqualTo(s.chunks[i - 1].ordinal),
          reason: '${n.title}: chunks out of reading order',
        );
      }
      if (n.type == GraphNodeType.sealed) {
        expect(s.chunks, isEmpty, reason: 'a sealed document leaks chunks');
      } else {
        expect(s.chunks, isNotEmpty, reason: '${n.title} has no chunks');
      }
      chunksByDoc[n.id] = ids.toSet();
      lines.add('${n.type.name} "${n.title}" -> ${s.chunks.length} chunks');
      ctl.collapse();
    }

    // Collapsing leaves nothing behind.
    expect(c.read(graphExpansionProvider).isExpanded, isFalse);

    // A document that does not exist is a clean not_found.
    await ctl.toggle('00000000-0000-4000-8000-000000000000');
    final missing = c.read(graphExpansionProvider);
    expect(missing.load, ChunkLoad.failed);
    expect(
      missing.error,
      isA<RequestRejectedException>().having(
        (e) => e.code,
        'code',
        'not_found',
      ),
    );
    ctl.collapse();

    // Independent cross-check: ask a real question; every chunk the answer
    // cites must be one the graph lists under that same document.
    final chat = c.read(chatControllerProvider.notifier);
    await chat.send('How is authentication handled in Cerebro?');
    final state = c.read(chatControllerProvider);
    addTearDown(() async {
      final id = state.sessionId;
      if (id != null) {
        await generated.apiV1ChatSessionsSessionIdDelete(sessionId: id);
      }
    });
    final answer = state.messages.last;
    expect(
      answer.citedDocuments,
      isNotEmpty,
      reason: 'the answer cited nothing to cross-check',
    );
    answer.citedDocuments.forEach((chunkId, documentId) {
      expect(
        chunksByDoc[documentId],
        contains(chunkId),
        reason:
            'cited chunk $chunkId is not among the graph chunks of '
            'document $documentId',
      );
    });
    // ignore: avoid_print
    print('REAL CHUNKS');
    // ignore: avoid_print
    lines.forEach(print);
    // ignore: avoid_print
    print(
      'CROSS-CHECK: ${answer.citedDocuments.length} cited chunk(s) all '
      "found in their documents' chunk lists",
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}
