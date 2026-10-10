// Milestone 4.1 functional test against the REAL backend: the user's real
// graph maps into the package's graph with one node per real document. Gated
// like the other real-backend suites: needs
// --dart-define=CEREBRO_TEST_EMAIL=... and CEREBRO_TEST_PASSWORD=... for a
// confirmed account. Read-only: it never reclusters or changes anything.
import 'dart:convert';

import 'package:cerebro_mobile/core/config/supabase_config.dart';
import 'package:cerebro_mobile/core/network/generated_api_client.dart';
import 'package:cerebro_mobile/core/network/session_token_provider.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository.dart';
import 'package:cerebro_mobile/features/graph/data/graph_api.dart';
import 'package:cerebro_mobile/features/graph/data/graph_layout.dart';
import 'package:cerebro_mobile/features/graph/data/graph_models.dart';
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
}
