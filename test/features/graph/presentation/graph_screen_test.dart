// The graph screen against a controllable fake API.
import 'dart:async';

import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/graph/data/graph_api.dart';
import 'package:cerebro_mobile/features/graph/data/graph_layout.dart';
import 'package:cerebro_mobile/features/graph/data/graph_models.dart';
import 'package:cerebro_mobile/features/graph/presentation/graph_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:cerebro_mobile/shared/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_force_directed_graph/flutter_force_directed_graph.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

GraphNodeData _n(
  String id, {
  String? title,
  double? x,
  double? y,
  String? mime = 'text/plain',
  String status = 'ready',
}) => GraphNodeData(
  id: id,
  title: title ?? id,
  x: x,
  y: y,
  mime: mime,
  status: status,
  clusterId: x == null ? null : 'c1',
);

class _FakeGraph implements GraphApi {
  List<GraphNodeData> nodeRows = [];
  List<GraphEdgeData> edgeRows = [];
  Object? nodesError;
  Object? edgesError;
  Completer<void>? nodesGate;
  int nodeCalls = 0;

  @override
  Future<List<GraphNodeData>> nodes() async {
    nodeCalls++;
    await nodesGate?.future;
    if (nodesError != null) throw nodesError!;
    return List.of(nodeRows);
  }

  @override
  Future<List<GraphEdgeData>> edges() async {
    if (edgesError != null) throw edgesError!;
    return List.of(edgeRows);
  }

  Map<String, List<ChunkSatellite>> chunkRows = {};
  Map<String, Completer<void>> chunkGates = {};
  Object? chunksError;
  final chunkCalls = <String>[];

  @override
  Future<List<ChunkSatellite>> chunks(String documentId) async {
    chunkCalls.add(documentId);
    await chunkGates[documentId]?.future;
    if (chunksError != null) throw chunksError!;
    return chunkRows[documentId] ?? const [];
  }
}

Future<List<String>> _pump(
  WidgetTester tester,
  _FakeGraph api, {
  List<String>? opened,
}) async {
  final out = opened ?? <String>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('u1'),
        graphApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: GraphScreen(openDocument: (_, id) => out.add(id)),
      ),
    ),
  );
  // First frame builds the screen, the next centers the graph, and the one
  // after that builds every node the package now knows to be on screen.
  await tester.pump();
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return out;
}

Finder _dot(String id) => find.byKey(Key('graph_node_$id'));

Color _colorOf(WidgetTester tester, String id) {
  final box = tester.widget<Container>(_dot(id));
  return (box.decoration! as BoxDecoration).color!;
}

void main() {
  testWidgets('shows a spinner while loading, then the graph', (tester) async {
    final api = _FakeGraph()
      ..nodeRows = [_n('a', x: 0, y: 0)]
      ..nodesGate = Completer<void>();
    await _pump(tester, api);
    expect(find.byKey(const Key('graph_loading')), findsOneWidget);

    api.nodesGate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('graph_loading')), findsNothing);
    expect(find.byKey(const Key('graph_canvas')), findsOneWidget);
  });

  testWidgets('draws one dot per document, the number the API reported', (
    tester,
  ) async {
    final api = _FakeGraph()
      ..nodeRows = [
        for (var i = 0; i < 12; i++)
          _n('n$i', x: (i % 4 - 1.5), y: (i ~/ 4 - 1)),
      ];
    await _pump(tester, api);
    expect(find.byKey(const Key('graph_canvas')), findsOneWidget);
    for (var i = 0; i < 12; i++) {
      expect(_dot('n$i'), findsOneWidget, reason: 'node n$i is missing');
    }
  });

  testWidgets('colors follow the document type: sealed amber, image teal, '
      'document violet', (tester) async {
    final api = _FakeGraph()
      ..nodeRows = [
        _n('doc', x: -1, y: 0, mime: 'application/pdf'),
        _n('img', x: 0, y: 0, mime: 'image/png'),
        _n('seal', x: 1, y: 0, mime: 'image/png', status: 'sealed'),
      ];
    await _pump(tester, api);
    expect(_colorOf(tester, 'doc'), AppColors.accentPrimary);
    expect(_colorOf(tester, 'img'), AppColors.accentSecondary);
    expect(_colorOf(tester, 'seal'), AppColors.accentLocked);
  });

  testWidgets('dots are not larger than the touch target and no smaller to '
      'tap', (tester) async {
    final api = _FakeGraph()..nodeRows = [_n('a', x: 0, y: 0)];
    await _pump(tester, api);
    final target = tester.getSize(
      find.ancestor(of: _dot('a'), matching: find.byType(SizedBox)).first,
    );
    expect(target.width, greaterThanOrEqualTo(44));
    expect(target.height, greaterThanOrEqualTo(44));
  });

  testWidgets('an empty library says so', (tester) async {
    await _pump(tester, _FakeGraph());
    expect(find.byKey(const Key('graph_empty')), findsOneWidget);
    expect(find.byKey(const Key('graph_canvas')), findsNothing);
  });

  testWidgets('a failed load shows the error with a working retry', (
    tester,
  ) async {
    final api = _FakeGraph()..nodesError = const NetworkUnreachableException();
    await _pump(tester, api);
    expect(find.byKey(const Key('graph_error')), findsOneWidget);

    api
      ..nodesError = null
      ..nodeRows = [_n('a', x: 0, y: 0)];
    await tester.tap(find.byKey(const Key('error_view_retry')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('graph_error')), findsNothing);
    expect(_dot('a'), findsOneWidget);
  });

  testWidgets('says plainly when groups are not computed yet', (tester) async {
    final api = _FakeGraph()..nodeRows = [_n('a'), _n('b'), _n('c')];
    await _pump(tester, api);
    expect(find.byKey(const Key('graph_notes')), findsOneWidget);
    expect(find.textContaining('not computed yet'), findsOneWidget);
    for (final id in ['a', 'b', 'c']) {
      expect(_dot(id), findsOneWidget);
    }
  });

  testWidgets('no note once the server has placed the documents', (
    tester,
  ) async {
    final api = _FakeGraph()
      ..nodeRows = [_n('a', x: 0, y: 0), _n('b', x: 1, y: 1)];
    await _pump(tester, api);
    expect(find.byKey(const Key('graph_notes')), findsNothing);
  });

  testWidgets('edges failing still draws the nodes and says links are '
      'missing', (tester) async {
    final api = _FakeGraph()
      ..nodeRows = [_n('a', x: 0, y: 0), _n('b', x: 1, y: 1)]
      ..edgesError = const NetworkUnreachableException();
    await _pump(tester, api);
    expect(_dot('a'), findsOneWidget);
    expect(find.textContaining("Links between documents"), findsOneWidget);
  });

  testWidgets('search counts matches and dims the rest', (tester) async {
    final api = _FakeGraph()
      ..nodeRows = [
        _n('a', title: 'Auth notes', x: -1, y: 0),
        _n('b', title: 'Billing', x: 1, y: 0),
      ];
    await _pump(tester, api);

    await tester.enterText(find.byType(TextField).first, 'auth');
    await tester.pump();

    expect(_colorOf(tester, 'a').a, 1.0);
    expect(_colorOf(tester, 'b').a, lessThan(0.5), reason: 'not dimmed');
    expect(find.text('Auth notes'), findsOneWidget, reason: 'match label');
  });

  testWidgets('tapping a node opens its sheet; Open in Documents opens that '
      'document', (tester) async {
    final api = _FakeGraph()
      ..nodeRows = [
        _n('a', title: 'Zanzibar notes', x: -1, y: 0),
        _n('b', title: 'Other', x: 1, y: 0),
      ];
    final opened = await _pump(tester, api);

    // The package paints (and hit-tests) nodes with its own transform, so a
    // finder's center is not where the node is: the view's middle plus the
    // node's offset (x: -1 of 1 fitted to the layout radius).
    final middle = tester.getCenter(find.byKey(const Key('graph_canvas')));
    await tester.tapAt(middle + const Offset(-graphLayoutRadius, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // In the panel (the node's own label is left off so it does not sit on
    // its satellites).
    expect(find.text('Zanzibar notes'), findsOneWidget);
    expect(find.text('Open in Documents'), findsOneWidget);

    await tester.tap(find.text('Open in Documents'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(opened, ['a']);
  });

  testWidgets('touching a node leaves the server layout alone — the package '
      'would otherwise start a physics run that scatters the documents', (
    tester,
  ) async {
    // Close together, so the package's repulsion would shove them apart.
    final api = _FakeGraph()
      ..nodeRows = [
        _n('a', x: -1, y: 0),
        _n('b', x: -0.8, y: 0),
        _n('c', x: -0.6, y: 0.2),
        _n('far', x: 1, y: 0),
      ];
    await _pump(tester, api);
    final controller = tester
        .widget<ForceDirectedGraphWidget<String>>(
          find.byKey(const Key('graph_canvas')),
        )
        .controller;
    Map<String, Offset> positions() => {
      for (final n in controller.graph.nodes)
        n.data: Offset(n.position.x, n.position.y),
    };
    final before = positions();

    // Press on 'a', drag it a little, let go.
    final middle = tester.getCenter(find.byKey(const Key('graph_canvas')));
    final gesture = await tester.startGesture(
      middle + Offset(before['a']!.dx, -before['a']!.dy),
    );
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    await gesture.up();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final after = positions();
    for (final id in ['b', 'c', 'far']) {
      expect(
        after[id],
        before[id],
        reason: 'untouched node $id was moved by physics',
      );
    }
    expect(
      controller.graph.updateAllNodes(),
      isFalse,
      reason: 'physics is still running',
    );
  });

  testWidgets('a seed-scale graph (300 documents, 900 links) renders without '
      'errors', (tester) async {
    final api = _FakeGraph()
      ..nodeRows = [
        for (var i = 0; i < 300; i++)
          _n(
            'd$i',
            x: (i % 20 - 10).toDouble(),
            y: (i ~/ 20 - 7).toDouble(),
            mime: i % 4 == 0 ? 'image/png' : 'text/plain',
          ),
      ]
      ..edgeRows = [
        for (var i = 0; i < 300; i++)
          for (var k = 1; k <= 3; k++)
            GraphEdgeData(from: 'd$i', to: 'd${(i * 7 + k * 13) % 300}'),
      ];
    final clock = Stopwatch()..start();
    await _pump(tester, api);
    clock.stop();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('graph_canvas')), findsOneWidget);
    final built = find.byWidgetPredicate(
      (w) => w.key.toString().startsWith("[<'graph_node_"),
    );
    expect(built, findsWidgets);
    // ignore: avoid_print
    print(
      'SEED-SCALE: ${built.evaluate().length} of 300 nodes built on screen; '
      'first render ${clock.elapsedMilliseconds}ms (test host, not a device)',
    );
  });

  testWidgets('refresh fetches again and keeps the graph up meanwhile', (
    tester,
  ) async {
    final api = _FakeGraph()..nodeRows = [_n('a', x: 0, y: 0)];
    await _pump(tester, api);
    expect(api.nodeCalls, 1);

    api.nodeRows = [_n('a', x: 0, y: 0), _n('b', x: 1, y: 1)];
    api.nodesGate = Completer<void>();
    await tester.tap(find.byKey(const Key('graph_refresh')));
    await tester.pump();
    expect(_dot('a'), findsOneWidget, reason: 'graph vanished mid-refresh');
    expect(_dot('b'), findsNothing);

    api.nodesGate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(api.nodeCalls, 2);
    expect(_dot('b'), findsOneWidget);
  });
}
