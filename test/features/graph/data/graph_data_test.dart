// The graph's data layer: parsing the API, mapping it into the package's
// graph, and the provider that loads it.
import 'dart:async';
import 'dart:math' as math;

import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/graph/data/graph_api.dart';
import 'package:cerebro_mobile/features/graph/data/graph_layout.dart';
import 'package:cerebro_mobile/features/graph/data/graph_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

GraphNodeData _n(
  String id, {
  double? x,
  double? y,
  String? mime,
  String? status = 'ready',
  String? cluster,
}) => GraphNodeData(
  id: id,
  title: id,
  x: x,
  y: y,
  mime: mime,
  status: status,
  clusterId: cluster,
);

void main() {
  group('GraphNodeData.fromJson', () {
    test('a clustered node', () {
      final n = GraphNodeData.fromJson({
        'id': 'a',
        'title': ' Notes ',
        'mime': 'text/plain',
        'status': 'ready',
        'cluster_id': 'c1',
        'x': 1,
        'y': -2.5,
        'z': 0.3,
      })!;
      expect(n.id, 'a');
      expect(n.title, 'Notes');
      expect(n.clusterId, 'c1');
      expect((n.x, n.y), (1.0, -2.5));
      expect(n.hasPosition, isTrue);
    });

    test('a node not yet clustered keeps its place in the list', () {
      final n = GraphNodeData.fromJson({
        'id': 'a',
        'title': 'New',
        'mime': 'text/plain',
        'status': 'ready',
        'cluster_id': null,
        'x': null,
        'y': null,
        'z': null,
      })!;
      expect(n.clusterId, isNull);
      expect(n.hasPosition, isFalse);
    });

    test('type: sealed beats image beats document', () {
      expect(
        _n('a', mime: 'image/png', status: 'sealed').type,
        GraphNodeType.sealed,
      );
      expect(_n('a', mime: 'image/jpeg').type, GraphNodeType.image);
      expect(_n('a', mime: 'application/pdf').type, GraphNodeType.document);
      expect(_n('a', mime: null, status: null).type, GraphNodeType.document);
    });

    test('rows that cannot be drawn are skipped, odd fields degrade', () {
      expect(GraphNodeData.fromJson('row'), isNull);
      expect(GraphNodeData.fromJson({'title': 'no id'}), isNull);
      expect(GraphNodeData.fromJson({'id': ''}), isNull);
      expect(GraphNodeData.fromJson({'id': 5}), isNull);

      final n = GraphNodeData.fromJson({
        'id': 'a',
        'title': '   ',
        'cluster_id': 7,
        'x': double.nan,
        'y': double.infinity,
        'mime': 3,
        'status': ['x'],
      })!;
      expect(n.title, 'Untitled');
      expect(n.clusterId, isNull);
      expect(n.hasPosition, isFalse, reason: 'NaN/inf are not positions');
      expect(n.type, GraphNodeType.document);
    });

    test('one coordinate alone is not a position', () {
      expect(_n('a', x: 1).hasPosition, isFalse);
      expect(_n('a', y: 1).hasPosition, isFalse);
    });
  });

  group('GraphEdgeData.fromJson', () {
    test('a kNN edge', () {
      final e = GraphEdgeData.fromJson({
        'document_id': 'a',
        'neighbor_document_id': 'b',
        'distance': 0.4,
        'rank': 1,
      })!;
      expect((e.from, e.to, e.distance, e.rank), ('a', 'b', 0.4, 1));
    });

    test('rows missing an end are skipped', () {
      expect(GraphEdgeData.fromJson({'document_id': 'a'}), isNull);
      expect(GraphEdgeData.fromJson({'neighbor_document_id': 'a'}), isNull);
      expect(
        GraphEdgeData.fromJson({
          'document_id': '',
          'neighbor_document_id': 'b',
        }),
        isNull,
      );
      expect(GraphEdgeData.fromJson(null), isNull);
    });
  });

  group('buildForceGraph', () {
    test('one graph node per document', () {
      final g = buildForceGraph(
        GraphSnapshot(
          nodes: [for (var i = 0; i < 18; i++) _n('n$i')],
          edges: const [],
        ),
      );
      expect(g.nodes, hasLength(18));
      expect(g.nodes.map((n) => n.data).toSet(), hasLength(18));
    });

    test('an empty library is an empty graph, not an error', () {
      final g = buildForceGraph(const GraphSnapshot(nodes: [], edges: []));
      expect(g.nodes, isEmpty);
      expect(g.edges, isEmpty);
    });

    test('a repeated id is one node', () {
      final g = buildForceGraph(
        GraphSnapshot(nodes: [_n('a'), _n('a'), _n('b')], edges: const []),
      );
      expect(g.nodes.map((n) => n.data), ['a', 'b']);
    });

    test(
      'server positions are kept in proportion and fitted to the radius',
      () {
        final g = buildForceGraph(
          GraphSnapshot(
            nodes: [
              _n('far', x: 4, y: 0),
              _n('half', x: 2, y: 0),
              _n('up', x: 0, y: -4),
            ],
            edges: const [],
          ),
        );
        final p = {for (final n in g.nodes) n.data: n.position};
        expect(p['far']!.x, closeTo(graphLayoutRadius, 1e-9));
        expect(p['half']!.x, closeTo(graphLayoutRadius / 2, 1e-9));
        expect(p['up']!.y, closeTo(-graphLayoutRadius, 1e-9));
      },
    );

    test('nodes the server has not placed are spread, and the same every '
        'time', () {
      GraphSnapshot snap() => GraphSnapshot(
        nodes: [for (var i = 0; i < 60; i++) _n('n$i')],
        edges: const [],
      );
      final a = buildForceGraph(snap());
      final b = buildForceGraph(snap());

      expect(
        [for (final n in a.nodes) (n.position.x, n.position.y)],
        [for (final n in b.nodes) (n.position.x, n.position.y)],
        reason: 'the layout must not be random',
      );
      var closest = double.infinity;
      for (var i = 0; i < a.nodes.length; i++) {
        for (var j = i + 1; j < a.nodes.length; j++) {
          closest = math.min(
            closest,
            a.nodes[i].position.distanceTo(a.nodes[j].position),
          );
        }
      }
      expect(closest, greaterThan(20), reason: 'unplaced nodes overlap');
    });

    test('the seed-scale graph (300 documents, 900 links) maps quickly', () {
      final nodes = [
        for (var i = 0; i < 300; i++)
          _n('d$i', x: math.cos(i) * (1 + i % 7), y: math.sin(i) * (1 + i % 5)),
      ];
      final edges = [
        for (var i = 0; i < 300; i++)
          for (var k = 1; k <= 3; k++)
            GraphEdgeData(from: 'd$i', to: 'd${(i * 7 + k * 13) % 300}'),
      ];
      final clock = Stopwatch()..start();
      final g = buildForceGraph(GraphSnapshot(nodes: nodes, edges: edges));
      clock.stop();
      expect(g.nodes, hasLength(300));
      expect(g.edges.length, inInclusiveRange(300, 900));
      expect(
        clock.elapsedMilliseconds,
        lessThan(250),
        reason: 'mapping 300 documents took ${clock.elapsedMilliseconds}ms',
      );
    });

    test('a document keeps its spot whatever order the server lists the '
        'documents in', () {
      final ids = [for (var i = 0; i < 20; i++) 'doc-$i'];
      Map<String, (double, double)> layout(List<String> order) {
        final g = buildForceGraph(
          GraphSnapshot(
            nodes: [for (final id in order) _n(id)],
            edges: const [],
          ),
        );
        return {for (final n in g.nodes) n.data: (n.position.x, n.position.y)};
      }

      final asListed = layout(ids);
      final reversed = layout(ids.reversed.toList());
      final shuffled = layout([...ids]..shuffle(math.Random(7)));
      expect(reversed, asListed, reason: 'documents hopped when reordered');
      expect(shuffled, asListed);
    });

    test(
      'placed and unplaced nodes mix without collapsing onto each other',
      () {
        final g = buildForceGraph(
          GraphSnapshot(
            nodes: [_n('placed', x: 1, y: 1), _n('new1'), _n('new2')],
            edges: const [],
          ),
        );
        final ps = g.nodes.map((n) => n.position).toList();
        expect(ps[0].distanceTo(ps[1]), greaterThan(10));
        expect(ps[1].distanceTo(ps[2]), greaterThan(10));
      },
    );

    test('nothing moves: every node is static', () {
      final g = buildForceGraph(
        GraphSnapshot(
          nodes: [_n('a', x: 1, y: 1), _n('b', x: -1, y: 2), _n('c')],
          edges: [const GraphEdgeData(from: 'a', to: 'b')],
        ),
      );
      final before = [for (final n in g.nodes) n.position.clone()];
      for (var i = 0; i < 20; i++) {
        expect(g.updateAllNodes(), isFalse, reason: 'physics is still running');
      }
      for (var i = 0; i < g.nodes.length; i++) {
        expect(g.nodes[i].position, before[i]);
      }
    });

    test('links to a document that is gone, self-links and duplicates are '
        'dropped', () {
      final g = buildForceGraph(
        GraphSnapshot(
          nodes: [_n('a'), _n('b'), _n('c')],
          edges: const [
            GraphEdgeData(from: 'a', to: 'b'),
            GraphEdgeData(from: 'b', to: 'a'), // the same link, reversed
            GraphEdgeData(from: 'a', to: 'a'), // to itself
            GraphEdgeData(from: 'a', to: 'deleted'), // stale
            GraphEdgeData(from: 'ghost', to: 'b'), // stale
            GraphEdgeData(from: 'b', to: 'c'),
          ],
        ),
      );
      expect(g.edges, hasLength(2));
    });
  });

  group('graphProvider', () {
    test('loads nodes and edges', () async {
      final api = _Api(
        nodes: [_n('a'), _n('b')],
        edgeRows: const [GraphEdgeData(from: 'a', to: 'b')],
      );
      final c = _container(api);
      final snap = await c.read(graphProvider.future);
      expect(snap.nodes, hasLength(2));
      expect(snap.edges, hasLength(1));
      expect(snap.edgesUnavailable, isFalse);
      expect(snap.isClustered, isFalse);
    });

    test('isClustered once any node has a position', () async {
      final c = _container(_Api(nodes: [_n('a', x: 1, y: 1), _n('b')]));
      expect((await c.read(graphProvider.future)).isClustered, isTrue);
    });

    test(
      'edges failing still shows the graph, and says edges are missing',
      () async {
        final c = _container(
          _Api(
            nodes: [_n('a')],
            edgesError: const NetworkUnreachableException(),
          ),
        );
        final snap = await c.read(graphProvider.future);
        expect(snap.nodes, hasLength(1));
        expect(snap.edges, isEmpty);
        expect(snap.edgesUnavailable, isTrue);
      },
    );

    test('nodes failing is an error', () async {
      final c = _container(
        _Api(nodes: const [], nodesError: const ServerErrorException(500)),
      );
      await expectLater(
        c.read(graphProvider.future),
        throwsA(isA<ServerErrorException>()),
      );
    });

    test('signed out: an empty graph, no request', () async {
      final api = _Api(nodes: [_n('a')]);
      final c = _container(api, user: null);
      expect((await c.read(graphProvider.future)).nodes, isEmpty);
      expect(api.nodeCalls, 0);
    });

    test('a refresh still in flight when the user changes never lands in the '
        "next user's graph", () async {
      final api = _Api(nodes: [_n('u1-doc')]);
      final user = StateProvider<String?>((_) => 'u1');
      final c = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => ref.watch(user)),
          graphApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(c.dispose);
      c.listen(graphProvider, (_, _) {});
      await c.read(graphProvider.future);

      // u1 refreshes; the answer is slow…
      final gate = Completer<void>();
      api.nodesGate = gate;
      final refreshing = c.read(graphProvider.notifier).refresh();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // …and meanwhile u2 signs in, whose own load is quick: it lands first.
      api.nodesGate = null;
      c.read(user.notifier).state = 'u2';
      api.nodes_ = [_n('u2-doc')];
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.read(graphProvider).valueOrNull?.nodes.map((n) => n.id), [
        'u2-doc',
      ]);

      // Only now does u1's slow answer arrive. It must be dropped.
      gate.complete();
      await refreshing;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final ids = c.read(graphProvider).valueOrNull?.nodes.map((n) => n.id);
      expect(ids, isNot(contains('u1-doc')));
    });

    test('a slow answer for the previous user never lands in the next '
        "user's graph", () async {
      final gate = Completer<void>();
      final api = _Api(nodes: [_n('old-user-doc')], nodesGate: gate);
      final user = StateProvider<String?>((_) => 'u1');
      final c = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => ref.watch(user)),
          graphApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(c.dispose);
      c.listen(graphProvider, (_, _) {});

      await Future<void>.delayed(const Duration(milliseconds: 5));
      c.read(user.notifier).state = 'u2';
      api.nodes_ = [_n('new-user-doc')];
      gate.complete();
      final snap = await c.read(graphProvider.future);
      expect(snap.nodes.map((n) => n.id), isNot(contains('old-user-doc')));
    });
  });
}

ProviderContainer _container(_Api api, {String? user = 'u1'}) {
  final c = ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWithValue(user),
      graphApiProvider.overrideWithValue(api),
    ],
  );
  addTearDown(c.dispose);
  c.listen(graphProvider, (_, _) {});
  return c;
}

class _Api implements GraphApi {
  _Api({
    required List<GraphNodeData> nodes,
    this.edgeRows = const [],
    this.nodesError,
    this.edgesError,
    this.nodesGate,
  }) : nodes_ = nodes;

  List<GraphNodeData> nodes_;
  final List<GraphEdgeData> edgeRows;
  final Object? nodesError;
  final Object? edgesError;
  Completer<void>? nodesGate;
  int nodeCalls = 0;

  @override
  Future<List<GraphNodeData>> nodes() async {
    nodeCalls++;
    // What a real request would carry: the answer is fixed when it is asked.
    final rows = nodes_;
    await nodesGate?.future;
    if (nodesError != null) throw nodesError!;
    return rows;
  }

  @override
  Future<List<GraphEdgeData>> edges() async {
    if (edgesError != null) throw edgesError!;
    return edgeRows;
  }

  @override
  Future<List<ChunkSatellite>> chunks(String documentId) async => const [];
}
